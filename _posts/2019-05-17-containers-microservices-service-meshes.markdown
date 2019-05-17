---
layout: post
title: "Containers, microservices, and service meshes"
---

There is
[a](https://containerjournal.com/2018/12/12/what-is-service-mesh-and-why-do-we-need-it/)
[lot](https://www.nginx.com/blog/do-i-need-a-service-mesh/)
[of](https://www.oreilly.com/ideas/do-you-need-a-service-mesh)
[material](https://www.datawire.io/envoyproxy/service-mesh/)
out there about services meshes, and this is another one. Yay!
But why? Because I would like to give you the perspective of
someone who wish service meshes did exist 10 years ago,
long before the rise of container platforms like Docker and
Kubernetes. I'm not claiming that this perspective is better
or worse than others, but since service meshes are rather
complex beasts, I believe that a multiplicity of points of
view can help to understand them better.

I will talk about the dotCloud platform, a platform that was
built on 100+ microservices and which supported thousands of
production applications running in containers;
I will explain the challenges that
were faced when building and running it; and how service meshes
would (or wouldn't) have helped.


## dotCloud history

I've already written about the history of the dotCloud platform
and some of its design choices, but I hadn't talked much about
its networking layer. If you don't want to dive into my
[previous blog post] about dotCloud, all you need to know is
that it was a PaaS allowing customers to run
a wide range of applications (Java, PHP, Python...) supported
by a wide range of data services (MongoDB, MySQL, Redis...)
and with a workflow similar to the one of Heroku: you would
push your code to the platform, the platform would build
container images, and deploy these container images.

I will tell you how traffic was routed on the dotCloud
platform; not because it was particularly great or anything
(I think it was okay for the time!) but primarily because
it's the kind of design that could be easily implemented
with today's tools by a modest team in a short amount
of time, if they needed a way to route traffic between
a bunch of microservices or a bunch of applications.
So it will give us a good comparison point between
"what we'd get if we hacked it ourselves" vs.
"what we'd get if we used an existing service mesh",
aka the good old "build vs. buy" quandary.


## Traffic routing for hosted applications

Applications deployed on dotCloud could expose HTTP and TCP
endpoints.

**HTTP endpoints** were dynamically added to the
configuration of a cluster of [Hipache] load balancers.
This is similar to what we can achieve today with Kubernetes
[Ingress] ressources and a load balancer like [Traefik].

Clients could connect to HTTP endpoints using their associated
domain names, provided that the domain name would point to
dotCloud's load balancers. Nothing fancy here.

**TCP endpoints** were associated with a port number,
that was then communicated to all the containers of that
stack through environment variables.

Clients could connect to TCP endpoints using a specified
host name (something like gateway-X.dotcloud.com) and that
port number.

That host name would resolve to a cluster of "nats" servers
(no relationship whatsoever with [NATS]) that would route
incoming TCP connections to the right container (or, in the
case of load-balanced services, to the right container*s*).

If you're familiar with Kubernetes, this will probably remind
you of [NodePort] services.

The dotCloud platform didn't have the equivalent of [ClusterIP]
services: for simplicity, services were accessed the same way
from the inside and from the outside of the platform.

This was simple enough that the initial implementations of
the HTTP and TCP routing meshes were probably a few hundreds
line of Python each, using fairly simple (I'd dare say, naive)
algorithms, but evolved over time to handle the growth of
the platform and additional requirements.

It didn't require extensive refactoring of existing application
code. [Twelve-factor applications] in particular could directly
use the address information provided through environment
variables.

## How was it different from a modern service mesh?

**Observability** was limited. There was no metrics at all
for the TCP routing mesh. As for the HTTP routing mesh, later versions
provided detailed HTTP metrics, showing error
codes and response times; but modern service meshes go above
and beyond, and provide integration with metrics collection
systems like Prometheus, for instance.

Observability is important not only from an operational
perspective (to help us troubleshoot issues), but also
to deliver features like safe [blue/green deployment] or
[canary deployments].

**Routing efficiency** was limited as well. In the dotCloud
routing mesh, all traffic had to go through a cluster of dedicated
routing nodes. This meant potentially crossing a few AZ
(availability zones) boundaries, and significantly increasing
the latency. I remember troubleshooting issues with some
code that was making 100+ SQL requests to display a given page,
and opening a new connection to the SQL server for each request.
When running locally, the page would load instantly, but when
running on dotCloud, it would take a few seconds, because each
TCP connection (and subsequent SQL request) would need dozens
of milliseconds to complete. In that specific case, using
persistent connections did the trick.

Modern service meshes do better than that. First of all,
by making sure that connections are routed *at the source*.
The logical flow is still `client → mesh → service`, but
now the mesh runs locally, instead of on remote nodes,
so the `client → mesh` connection is a local one, hence
very fast (microseconds instead of milliseconds).

Modern service meshes also implement smarter load-balancing
algorithms. By monitoring the health of the backends,
they can send more traffic on faster backends, resulting
in better overall performance.

**Security** is also stronger with modern service meshes.
The dotCloud routing mesh was running entirely on EC2 Classic,
and didn't encrypt traffic (on the assumption that if somebody
manages to sniff network traffic on EC2, you have bigger problems
anyway). Modern service meshes can transparently secure all
our traffic, for instance with mutual TLS authentication
and subsequent encryption.


## Traffic routing for platform services

Alright, we've discussed how applications communicated,
but what about the dotCloud platform itself?

The platform itself was composed of about 100 microservices,
responsible for various functions. Some of these services accepted
requests from others, and some of them were background workers
that would connect to other services, but not receive connections
on their own. Either way, each service needed to know the endpoints
of addresses it needed to connect to.

A lot of high-level services could use the routing mesh
described above. In fact, a good chunk of the 100+ microservices
of the dotCloud platform were deployed as normal applications
on the dotCloud platform itself. But a small number of low-level services
(specifically, the ones implementing that routing mesh)
needed something simpler, with less dependencies
(since they couldn't depend on themselves to function;
that's the good old "chicken-and-egg" problem).

These low-level, essential platform services were deployed by
starting containers directly on a few key nodes, instead of
relying on the platform's builder, scheduler, and runner services.
If you want a comparison with modern container platforms, that
would be like starting our control plane with `docker run`
directly on our nodes, instead of having Kubernetes doing it
for us. This was fairly similar to the concept of [static pods]
used by [kubeadm], or by [bootkube] when bootstrapping a self-hosted
cluster.

These services were exposed in a very simple and crude way:
there was a YAML file listing these services, mapping their
names to their addresses; and every consumer of these services
needed a copy of that YAML file as part of their deployment.

On the one hand, this was extremely robust, because it didn't
involve maintaining an external key/value store like Zookeeper
(remember, etcd or Consul didn't exist at that time). On the
other hand, it made it difficult to move services around.
Each time a service was moved, all its consumers would need
to receive an updated YAML file (and potentially be restarted).
Not very convenient!

The solution that we started to implement was to have every
consumer connect to a local proxy. Instead of knowing the
full address+port of a service, a consumer would only need
to know its port number, and connect over `localhost`.
The local proxy would handle that connection, and route it
to the actual backend. Now when a backend needs to be
moved to another machine, or scaled up or down, instead
of updating all its consumers, we only need to update all
these local proxies; and we don't need to restart consumers
anymore.

(There were also plans to encapsulate traffic in TLS
connections, and have another proxy on the receiving side
as well to unwrap TLS and verify certificates, without
involving the receiving service, which would be set up
to accept connections only on `localhost`. More on that later.)

This is quite similar to AirBNB's [SmartStack]; with the
notable difference that SmartStack *was* implemented and
deployed to production, while dotCloud's new internal routing mesh
ended up being shelved when dotCloud pivoted to Docker. ☺

I personally consider SmartStack as one of the precursors
of systems like Istio, Linkerd, Consul Connect ... because
all these systems follow that pattern:

- run a proxy on each node
- consumers connect to the proxy
- control plane updates the proxy's configuration when backends change
- ... profit!


## Implementing a service mesh today

If we had to implement a similar mesh today, we could
use similar principles. For instance, we could set up an internal
DNS zone, mapping service names to addresses in the `127.0.0.0/8`
space. Then run HAProxy on each node of our cluster, accepting
connections on each service address (in that `127.0.0.0/8` subnet)
and forwarding / load-balancing them to the appropriate backends.
HAProxy configuration could be managed by [confd], allowing to store
backend information in etcd or Consul, and automatically push
updated configuration to HAProxy when needed.

This is more or less how Istio works! But with a few differences:

- it uses [Envoy Proxy] instead of HAProxy
- it stores backend configuration using the Kubernetes API
  instead of etcd or Consul
- services are allocated addresses in an internal subnet
  (Kubernetes ClusterIP addresses) instead of `127.0.0.0/8`
- it has an extra component (Citadel) to add mutual TLS
  authentication between client and servers
- it adds support for new features like circuit breaking,
  distributed tracing, canary deployments ...

Let's quickly review some of these differences.


### Envoy Proxy

Envoy Proxy was written by Lyft. It has many similarities
with other proxies (like HAProxy, NGINX, Traefik...) but Lyft
wrote it because they needed features that didn't exist in these
other proxies at the time, and it made more sense to build a
new proxy than to extend an existing one.

Envoy can be used on its own. If I have a given service
that needs to connect to other services, I can set it up
to connect to Envoy instead, and then dynamically configure
and reconfigure Envoy with the location of my other services,
while getting a lot of nifty extra features, for instance in the
domain of observability. Instead of using a custom client library,
or peppering my code with tracing calls, I direct my traffic
to Envoy and let it collect metrics for me.

But Envoy can also be used as the *data plane* for a service mesh.
This means that Envoy will now be configured by the *control plane*
of that service mesh.


### Control plane

Speaking of the control plane: Istio relies on the Kubernetes API
for that purpose. *This is not very different from using confd.*
Confd relies on etcd or Consul to watch a set of keys in a data store.
Istio relies on the Kubernetes API to watch a set of Kubernetes resources.

*Aparté:* I personally found it really helpful to read this
[Kubernetes API description] that states:

> The Kubernetes API server is a "dumb server" which offers storage,
> versioning, validation, update, and watch semantics on API resources.

*End of aparté.*

Istio was designed to work with Kubernetes; and if you want to
use it outside of Kubernetes, you will need to run an instance
of the Kubernetes API server (and a supporting etcd service).


### Service addresses

Istio relies on Kubernetes' allocation of ClusterIP addresses,
so Istio services get an internal address (not in the `127.0.0.0/8` range).

On a Kubernetes cluster without Istio, traffic going to the
ClusterIP address for a given service is intercepted by kube-proxy,
and sent to a backend of that proxy. More specifically, if you
like to nail down the technical details: kube-proxy
sets up iptables rules (or IPVS load balancers, depending how
it was set up) to rewrite the destination IP addresses of connections
going the ClusterIP address.

Once Istio is installed on a Kubernetes cluster, nothing changes,
until it gets explicitly enabled for a given consumer or even
an entire namespace, by injecting a *sidecar* container into the
consumer pods. The sidecar will run an instance of Envoy, and
set up a number of iptables rules to intercept traffic going
to the other services and redirect that traffic to Envoy.

Combined with Kubernetes DNS integration, this means that our
code can connect to a service name, and everything "just works".
In other words, our code would issue a request to e.g. http://api/v1/users/4242,
`api` would resolve to `10.97.105.48`, an iptables rules would intercept
connections to `10.97.105.48` and redirect them to the local Envoy
proxy, and that local proxy would route the request to the actual
API backend. Phew!


### Extra bells and whistles

Istio can also provide end-to-end encryption and authentication
through mTLS (mutual TLS) with a component named *Citadel.*

It also features *Mixer*, a component that Envoy can query for
*every single* request, to make an ad-hoc decision about that
request depending on various factors like request headers, backend load...
(Don't worry: there are abundant provisions to make sure that
Mixer is highly available, and that even if it breaks, Envoy
can continue to proxy traffic.)

And of course, me mentioned observability: Envoy collects
a vast amount of metrics, while providing distributed tracing.
In a microservices architecture, if a single API request has
to go through microservices A, B, C, and D, distributed tracing
will add a unique identifier to the request when it enters the
system, and preserve that identifier across sub-requests to
all these microservices, allowing to gather all related calls,
their latencies, etc.


## Build vs. buy

Istio has the reputation of being complex. By contrast,
building a routing mesh like the one that I described in the
beginning of this post is relatively straightforward with the
tools that we have today. So, does it make sense to build
our own service mesh instead?

If we have modest needs (if we don't need observability,
circuit breaker, and other niceties) we might want to
build our own. But if we're using Kubernetes, we might not
even need to, because Kubernetes already provides basic
service discovery and load balancing.

Now, if we have advanced requirements, "buying" a service
mesh can be a much better option. (It's not always exactly
"buying" since Istio is open source, but we still have to
invest engineering time to understand how it works,
deploy, and operate it.)


## Istio vs. Linkerd vs. Consul Connect

So far, we only spoke about Istio, but it's not the only
service mesh out there. [Linkerd] is another popular option,
and there is also [Consul Connect].

Which one should we pick?

Honestly, I don't konw, and at this point, I don't
consider myself knowledgeable enough to help anyone make
that decision. There are some interesting
[articles](https://thenewstack.io/which-service-mesh-should-i-use/)
[comparing](https://medium.com/solo-io/linkerd-or-istio-6fcd2aad6e42)
them, and even [benchmarks](https://medium.com/@michael_87395/benchmarking-istio-linkerd-cpu-c36287e32781).

One approach that has a lot of potential is to use a tool
like [SuperGloo]. SuperGloo offers an abstraction layer to simplify
and unify the APIs exposed by service meshes. Instead of learning about
the specific (and, in my opinion, relatively complex) APIs of various
service meshes, we can use the simpler constructs offered by SuperGloo,
and switch seamlessly from one service mesh to another. A little bit as if
we had an intermediary configuration format describing HTTP frontends and
backends, and able to generate actual configuration for NGINX, HAProxy,
Traefik, Apache ...

I've dabbled a bit in Istio using SuperGloo, and in a future blog post,
I would like to illustrate how to add Istio or Linkerd to an existing cluster
using SuperGloo, and whether the latter holds its promise, i.e. allowing
me to switch from one routing mesh to another without rewriting configurations.

If you enjoyed that post and would like me to try out some specific scenarios,
I'd love to [hear from you](https://twitter.com/jpetazzo)!


[previous blog post]: http://jpetazzo.github.io/2017/02/24/from-dotcloud-to-docker/
[Hipache]: https://github.com/hipache/hipache
[Ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[Traefik]: https://traefik.io/
[NodePort]: https://kubernetes.io/docs/concepts/services-networking/service/#nodeport
[NATS]: https://nats.io/
[ClusterIP]: https://kubernetes.io/docs/concepts/services-networking/connect-applications-service/
[Twelve-factor applications]: https://12factor.net/
[blue/green deployment]: https://martinfowler.com/bliki/BlueGreenDeployment.html
[canary deployments]: https://martinfowler.com/bliki/CanaryRelease.html
[static pods]: https://kubernetes.io/docs/tasks/administer-cluster/static-pod/
[kubeadm]: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/
[bootkube]: https://github.com/kubernetes-incubator/bootkube
[SmartStack]: https://medium.com/airbnb-engineering/smartstack-service-discovery-in-the-cloud-4b8a080de619
[confd]: https://github.com/kelseyhightower/confd
[Envoy Proxy]: https://www.envoyproxy.io/
[Kubernetes API description]: https://github.com/kubernetes/community/blob/master/contributors/design-proposals/api-machinery/protobuf.md#proposal-and-motivation
[Linkerd]: https://linkerd.io/2/overview/
[Consul Connect]: https://learn.hashicorp.com/consul/getting-started-k8s/l7-observability-k8s
[SuperGloo]: https://supergloo.solo.io/
