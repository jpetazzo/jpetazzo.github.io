---
layout: post
title: "Understanding DNS resolution on Linux and Kubernetes"
---

I recently investigated a warning message on Kubernetes that said: `DNSConfigForming ... Nameserver limits were exceeded, some nameservers have been omitted`. This was technically a Kubernetes *event* with `type: Warning`, and these usually indicate that there's something wrong, so I wanted to investigate it.

This led me down a pretty deep rabbit hole about DNS resolution on Linux in general and Kubernetes in particular. I thought it might be helpful to others to explain how this all works, just in case you have to troubleshoot a DNS issue some day (and as we now, [it's always DNS][isitdns]) on Linux or on Kubernetes.


## Kubernetes DNS in theory

Kubernetes provides DNS-based service discovery. When we create a service named `foo` in namespace `bar`, Kubernetes creates a DNS entry, `foo.bar.svc.cluster.local`, that resolves to that service's `ClusterIP`.

Any pod in the cluster can resolve `foo.bar` or `foo.bar.svc` and obtain that service's `ClusterIP`. Any pod in the same `bar` namespace can even just resolve `foo` to obtain that `ClusterIP`.

This means that when we write code that will run on Kubernetes, if we need to connect to a database, we can put `db` as the database name (instead of hardcoding an IP address) or e.g. `db.prod` if we want to connect to service `db` in namespace `prod`.

This is convenient, because a similar mechanism exists in e.g. Docker Compose; which means that we can write code, test it with Docker Compose, and run it in Kubernetes without changing a single line of code. Cool.

Now, how does that work behind the scenes?


## DNS resolution on Linux (level 1: resolv.conf)

At a first glance, DNS resolution on Linux is configured through `/etc/resolv.conf`. A typical `resolv.conf` file can look like this:

```
nameserver 192.168.1.1
nameserver 192.168.1.2
search example.com example.net
```

This defines two DNS servers (for redundancy purposes; but in many cases you will only have one) as well as a "search list". This means that if we try to resolve the name `hello`, here is what will happen:

- first, we look for `hello.example.com`
- if that name doesn't exist, we look for `hello.example.net`
- if that name doesn't exist, we look for `hello`
- if that name doesn't exist, we report an error (like `Name or service not known`)

By default, only the first name server is used. The other name servers are queried only if the first one times out. This means that all name servers must serve exactly the same records. You cannot have, for instance, one name server for internal domains, and another one for external domains! If you send a query to the first server, and that server replies with "not found" (technically, an NXDOMAIN reply), the second server will not be queried - the "not found" error will be reported right away.

(Note: it is possible to use the option `rotate`, in which case name servers are queried in round-robin order to spread the query load. Name servers still need to have the same records, though; otherwise DNS replies might be inconsistent and that will cause some *very weird* errors down the line.)

There are some limits and "fine print":

- we can specify up to 3 name servers (additional name servers will be ignored);
- we can specify up to 6 search domains;
- the `ndots` option can be used to change whether (and when) to try the search list first, or an "initial absolute query" (i.e. `hello` without the search domain).

You can see extra details in the `resolv.conf(5)` man page, which explains for instance how to change timeout values, number of retries, and that kind of stuff.


## DNS resolution on Linux (level 2: nsswitch.conf)

Perhaps you've come across `.local` names. For instance, on my LAN at home, I can ping the machine named `zagreb` with `ping zagreb.local`:

```
$ ping -4 zagreb.local
PING zagreb.local (10.0.0.30) 56(84) bytes of data.
64 bytes from 10.0.0.30: icmp_seq=1 ttl=64 time=2.16 ms
...
```

This is sometimes called Zeroconf, or Bonjour, or Avahi, or mDNS. Without diving into these respective protocols and implementations, how does that fit in the system that we explained above?

This is because in reality, before using `/etc/resolv.conf`, the system will check `/etc/nsswitch.conf`. NSS is the "name service switch", and is used to configure many different name lookup services, including:

- hosts (mapping names to IP addresses)
- passwd (mapping user names to their UID and vice versa)
- services (mapping service names like `http`, `ftp`, `ssh` to port numbers and vice versa)

In that file, there might be a line looking like the following one:

```
hosts: files mymachines myhostname mdns_minimal [NOTFOUND=return] dns
```

There would be a lot to unpack there. I won't dive into all the little details because this is not relevant to Kubernetes, but this essentially means that when trying to resolve a host name, the system will look into:

- `files`, which means `/etc/hosts` (that's why we can hard-code some name and IP addresses in that file!);
- `mymachines`, which is something used for `systemd-machined` containers;
- `myhostname`, which automatically maps names like `localhost` to `127.0.0.1`, or our local host name to a local IP address;
- `mdns_minimal`, which resolves `.local` names;
- `dns`,  which is the traditional DNS resolver configured by `resolv.conf` as explained above.

You might also come across `resolve`, which uses `systemd-resolved` for name resolution. That's a totally different system with its own configuration and settings, and it's mostly irrelevant to Kubernetes, so we won't talk about it here.


## DNS resolution on Linux (level 3: musl and systemd-resolved)

Everything we explained in the two previous sections only applies to programs using the GNU libc, or "glibc". This is the system library used on *almost* every Linux distribution, with the notable exception of Alpine Linux, which uses musl instead of glibc.

The musl name resolver is much simpler: there is no NSS (name service switch), and DNS resolution is configured exclusively through `/etc/resolv.conf`. It also behaves a bit differently (it sends queries to all servers in parallel instead of one at a time). You can see more details in [this page][musl-glibc], which explains differences between musl and glibc.

This is relevant because Alpine is used in many container images, especially when optimizing container image size. Some images based on Alpine can be 10x smaller than their non-Alpine counterparts. Of course, the exact gains will depend a lot on the program, its dependencies, etc, but this explains why Alpine is quite common in the container ecosystem.

Additionally, if your system uses `systemd-resolved` (an optional component of `systemd`), the DNS configuration will look quite different.

When using `systemd-resolved`:

- the `systemd-resolved.service` unit will be running;
- in `/etc/nsswitch.conf`, on the `hosts:` line, the module `resolve` will be mentioned, indicating that host name resolution will use systemd-resolved over DBUS instead of "traditional" DNS queries over UDP or TCP;
- `/etc/resolv.conf` will be a symlink to `/run/systemd/resolve/stub-resolv.conf` and contain the line `nameserver 127.0.0.53`;
- `systemd-resolved` will expose a legacy resolver on `127.0.0.53`, for applications that wouldn't use the name service switch (for instance, applications linked with Alpine, or using Go native network libraries);
- DNS configuration will be done through `systemd` configuration files and/or with the `resolvectl` tool instead of editing `/etc/resolv.conf`;
- `/run/systemd/resolve/resolv.conf` will contain a compatibility configuration file listing the uplink DNS servers, to be used by applications requiring a "classic" `resolv.conf` file.

That last item is relevant to Kubernetes, as we will see later, because `kubelet` will sometimes need that `resolv.conf` file.


## DNS resolution on Kubernetes (level 1: kube-dns)

Equipped with all that DNS configuration knowledge, let's have a look at the `/etc/resolv.conf` file in a Kubernetes pod. That particular pod is in the `default` namespace, and its `resolv.conf` file will look like this:

```
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.10.0.10
options ndots:5
```

The `nameserver` line indicates to use the Kubernetes internal DNS server. The IP address here corresponds to the `ClusterIP` address of the `kube-dns` service in the `kube-system` namespace:

```
$ kubectl get service -n kube-system kube-dns
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.10.0.10   <none>        53/UDP,53/TCP,9153/TCP   9d
```

The exact IP address might be different in your cluster. It is often the 10th host address in the cluster IP service subnet, but that's not a hard rule.

That `kube-dns` service will typically be configured together with a `coredns` deployment; and that `coredns` deployment will be configured to serve Kubernetes DNS records (like the `foo.bar.svc.cluster.local` mentioned earlier) and to pass queries for external names to an upstream server.

Note: it's also possible to use something other than CoreDNS. In fact, early versions of Kubernetes (up to 1.10) used a custom server called `kube-dns`, and that's why the service still has that name. And some folks replace CoreDNS, or add a host-local cache, to improve performance and work around some issues in high-traffic scenarios. You can check [this KubeCon presentation][switching-dns-engine] for an example. (Even if it's a few years old, that presentation still does a great job at explaining DNS mechanisms, and the ideas and techniques that it explains are still highly releveant today!)

Now, let's look at the `search` line. It basically means that when we try to resolve `foo`, we'll try, in this order:

- `foo.default.svc.cluster.local`, which corresponds to "the `foo` service in the same namespace as the pod";
- `foo.svc.cluster.local`, which doesn't correspond to anything in that case, but would be useful if we were trying to resolve `foo.bar`, because it would then correspond to "the `foo` service in the `bar` namespace";
- `foo.cluster.local`, which again doesn't correspond to anything in that case, but would be useful if we were trying to resolve `foo.bar.svc`;
- `foo` on its own, which also doesn't resolve to anything.

This means that in our code, we can connect to, e.g.:

- `foo`, which will resolve to the `foo` service in the current namespace,
- `foo.bar`, which will resolve to the `foo` service in the `bar` namespace,
- `foo.bar.svc`, which will resolve to the same,
- `foo.bar.svc.cluster.local`, which also resolves to the same,
- `foo.example.com`, which will resolve with external DNS.

Phew! Well, of course, there are some little details to be aware of.


## DNS resolution on Kubernetes (level 2: customization)

Let's start with the easier things: the `cluster.local` suffix can be changed. It's typically configured when setting up the cluster, similarly to e.g. the Cluster IP subnet. It requires updating the kubelet configuration, as well as the CoreDNS configuration. Changing that suffix is rarely necessary, except if we want to connect multiple clusters together, and enable one cluster to resolve names of services running on another cluster. It's fairly unusual, except when running huge applications - huge in the sense that they won't fit on a single cluster; or we don't want to fit them on a single cluster for various reasons.

Then, what about the `svc` component? It's here because there is also `pod`, in other words, `pod.cluster.local`. The Kubernetes DNS resolves `A-B-C-D.N.pod.cluster.local` to `A.B.C.D`, as long as `A.B.C.D` is a valid IP address and `N` is an existing namespace. Let's be honest: I don't know how this serves any purpose, but if you do, please let me know!

Finally, there is that `options ndots:5`. This indicates "how many dots should there be in a name for that name to be considered an external name". In other words, if we try to resolve `a`, `a.b`, `a.b.c`, `a.b.c.d`, or `a.b.c.d.e`, the search list will be used - so resolving `api.example.com` will result in 5 DNS queries (for the 4 elements of the search list + the upstream query). But if we try to resolve `a.b.c.d.e.f`, since there are at least 5 dots, it will directly try an upstream query. (The default value for `ndots` is 1.)

This prompts a question: if we want to resolve `api.example.com`, how can we avoid the extraneous DNS queries? And another: if we want to resolve the external name `purple.dev` while also having a service named `purple` in namespace `dev`, what should we do? The answer to both questions is to add a dot at the end of the domain. Resolving `purple.dev.` will skip the `search` list, which means it won't incur extraneous DNS queries, and it will resolve the external name and never an internal Kubernetes name.

Is that all we need to know about Kubernetes DNS? Not quite.


## DNS resolution on Kubernetes (level 3: dnsPolicy)

"Normal" pods will have a DNS configuration like the one shown previously - reproduced here for convenience:

```
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.10.0.10
options ndots:5
```

But this can be changed by setting the `dnsPolicy` field in pod manifests.

It's possible to tell Kubernetes to use the DNS configuration of the host. This is used, for instance, in the CoreDNS pods, since they need to know which resolvers to query for external names. It's also used by some infrastructure, essential pods, that need to resolve external names but don't want to depend on the Kubernetes internal DNS to be available to function. (I've seen this with some CNI or CSI pods that need to connect to cloud providers' API endpoints.)

It's also possible to tell Kubernetes to use a completely arbitrary DNS configuration for a pod, specifying the DNS servers and search lists.

You can find all the details about that `dnsPolicy` field and its possible values in this [Kubernetes documentation page][pod-dns-policy].

When using the DNS configuration of the host, Kubernetes (technically, `kubelet`) will use `/etc/resolv.conf` on the host - or, if it detects that the host is using `systemd-resolved`, it will use `/run/systemd/resolve/resolv.conf` instead. There is also a `kubelet` option, `--resolv-conf`, to instruct it to use a different file.


## Back to `Nameserver limits were exceeded`

Let's come back to our error message.

When we tell Kubernetes to use the host's DNS configuration (either through an explicit `dnsPolicy: Default`, or an implicit one because the pod has `hostNetwork: true`, which is the case for `kube-proxy` and many CNI pods), it will obtain that configuration from `/etc/resolv.conf` on the host. We mentioned above that the DNS resolvers (both in glibc and musl) supported up to 3 name servers; extra name servers are ignored. If there are more than 3 resolvers configured in that file, Kubernetes will issue that warning, because it "knows" that the extra servers won't be used.

In legacy IPv4 environments, it's fairly rare to have more than 2 servers listed. However, in dual stack IPv4/IPv6 environments, it is quite possible to end up with more.

For instance, this server on Hetzner has two IPv4 servers and two IPv6 servers:

```
nameserver 2a01:4ff:ff00::add:1
nameserver 2a01:4ff:ff00::add:2
nameserver 185.12.64.1
nameserver 185.12.64.2
```

This machine has an IPv4 server, and one IPv6 server per interface, and has 3 interfaces:

```
nameserver 10.0.0.1
nameserver fe80::1%eno2
nameserver fe80::1%wlo1
nameserver fe80::1%enp0s20f0u3u4
```

In that case, kubelet will issue a warning - the `DNSConfigForming` that we mentioned at the beginning of this article - when creating the pod.

The warning is totally harmless (it doesn't indicate a configuration issue or potential problem with our pod), and the DNS behavior of our pod will not change at all. Remember: with the glibc resolver, we try each resolver in order anyway. It's great to have a second one as a backup, but 3 or 4 is often a bit excessive.

Still, how can we get rid of that warning?

That's where things can get a bit complicated.

If you have configured your DNS resolution manually (by editing `/etc/resolv.conf`), all you have to do is trim the list of name servers to have only 3 or less.

But it's likely that this configuration was provided automatically, generally by a DHCP client (on your LAN if this is your local machine, or by your hosting provider if this is a server somewhere). If you can update the configuration of the DHCP server so that it provides 3 name servers or less, great! If you can't, you will have to trim that list client-side.

It would be tempting to manually edit `/etc/resolv.conf` (or, when using `systemd-resolved`, `/run/systemd/resolve/resolv.conf`), but it will probably not be durable. First, it's almost guaranteed that this file will be regenerated when the machine is rebooted. Next, it's also very likely that this file will be regenerated at some point, either by the DHCP client or by `systemd-resolved`.

One possibility would be to trim the list of DNS servers received by the DHCP client. The exact method will depend on the DHCP client. On Ubuntu, the default DHCP client is `dhclient`, and DNS is configured with `dhclient-script`, which itself has a system of hooks. For instance, on a system using `systemd-resolved`, there is a script in `/etc/dhcp/dhclient-exit-hooks.d/resolved` to feed the DNS resolvers to `systemd-resolved`. The DNS resolvers are passed through the environment variable `$new_domain_name_servers`. It should be possible to drop a script in that directory, for instance `reduce-nameservers`, to change that variable. (Since `reduce-nameservers` is before `resolved`, it should be called before; but the `dhclient-script` documentation doesn't specify in which order the scripts get called.)

Unfortunately, in some scenarios, this will be even more complicated, because some name servers will be passed at boot time (and collected by systems like cloud-init, netplan...) and more name servers will be added by the DHCP client at a later point. This can also happen on system with multiple network interfaces, for instance connected to multiple virtual networks. These systems might receive a couple of DNS servers on each interface, and it looks like `systemd-resolved` will just happily aggregate all of them, causing `kubelet` to show us that warning.

Another approach (if it's feasible for you to control your `kubelet` configuration) is to point `kubelet` to a custom `resolv.conf` file, and generate that file from the existing `resolv.conf` file, keeping only the first 3 name servers. 

And of course, while these methods are relatively simple (especially when running on-prem, with a fixed set of nodes), they immediately require a lot of extra work when you want to bundle them into your node deployment process - for instance, when using managed nodes, and/or cluster autoscaling.


## Conclusions

Bad news: there isn't a fool-proof way to get rid of that `DNSConfigForming` warning.

Good news: it's totally harmless.

While this post didn't give us a way to easily and reliably get rid of that error message, we hope that it gave you lots of insightful details about how DNS works - on Kubernetes, but on modern Linux systems in general as well!

[isitdns]: https://isitdns.com/
[musl-glibc]: https://wiki.musl-libc.org/functional-differences-from-glibc.html
[switching-dns-engine]: https://www.youtube.com/watch?v=Il-yzqBrUdo
[pod-dns-policy]: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-s-dns-policy
