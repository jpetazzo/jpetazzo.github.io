---
layout: post
title: "Gathering container metrics"
---

Linux Containers rely on [control groups]
which not only track groups of processes, but also expose 
a lot of metrics about CPU, memory, and block I/O usage. 
We will see how to access those metrics, and how to obtain network usage metrics
as well. This is relevant for "pure" LXC containers, as well as for
Docker containers.


## Locate your control groups

Control groups are exposed through a pseudo-filesystem. In recent
distros, you should find this filesystem under `/sys/fs/cgroup`.
Under that directory, you will see multiple sub-directories, called
`devices`, `freezer`, `blkio`, etc.; each sub-directory actually
corresponds to a different cgroup *hierarchy*.

On older systems, the control groups might be mounted on `/cgroup`,
without distinct hierarchies. In that case, instead of seeing
the sub-directories, you will see a bunch of files in that directory,
and possibly some directories corresponding to existing containers.

To figure out where your control groups are mounted, you can run:

    grep cgroup /proc/mounts


### Control groups hierarchies

The fact that different control groups can be in different hierarchies
mean that you can use completely different groups (and policies)
for e.g. CPU allocation and memory allocation. Let's make up a completely
imaginary example: you have a 2-CPU system running Python webapps
with Gunicorn, a PostgreSQL database, and accepting SSH logins.
You can put each webapp and each SSH session in their own memory
control group (to make sure that a single app or user doesn't use up
the memory of the whole system), and at the same time, stick the
webapps and database on a CPU, and the SSH logins on another CPU.

Of course, if you run LXC containers, each hierarchy will have one
group per container, and all hierarchies will look the same.

Merging or splitting hierarchies is achieved by using special options
when mounting the cgroup pseudo-filesystems. Note that if you want
to change that, you will have to remove all existing cgroups in
the hierarchies that you want to split or merge.


### Enumerating our cgroups

You can look into `/proc/cgroups` to see the different control
group subsystems known to the system, the hierarchy they belong to, and
how many groups they contain.

You can also look at `/proc/<pid>/cgroup` to see which control groups
a process belongs to. The control group will be shown as a path relative
to the root of the hierarchy mountpoint; e.g. `/` means "this process
has not been assigned into a particular group", while `/lxc/pumpkin`
means that the process is likely to be a member of a container named
`pumpkin`.


### Finding the cgroup for a given container

For each container, one cgroup will be created in each hierarchy.
On older systems with older versions of the LXC userland tools, the
name of the cgroup will be the name of the container. With more
recent versions of the LXC tools, the cgroup will be `lxc/<container_name>`.

Additional note for Docker users: the container name will be the
*full ID* or *long ID* of the container. If a container shows up
as `ae836c95b4c3` in `docker ps`, its long ID might be something
like `ae836c95b4c3c9e9179e0e91015512da89fdec91612f63cebae57df9a5444c79`.
You can look it up with `docker inspect` or `docker ps -notrunc`.

Putting everything together: on my system, if I want to look at the
memory metrics for a Docker container, I have to look at
`/sys/fs/cgroup/memory/lxc/<longid>/`.


## Collecting memory, CPU, block I/O metrics

For each subsystem, we will find one pseudo-file (in some cases, multiple)
containing statistics about used memory, accumulated CPU cycles, or number
of I/O completed. Those files are easy to parse, as we will see.


### Memory metrics

Those will be found in the `memory` cgroup (duh!). Note that the memory
control group adds a little overhead, because it does very fine-grained
accounting of the memory usage on your system. Therefore, many distros
chose to *not* enable it by default. Generally, to enable it, all you
have to do is to add some kernel command-line parameters:
`cgroup_enable=memory swapaccount=1`.

The metrics are in the pseudo-file `memory.stat`. Here is what it will
look like:

```
cache 11492564992
rss 1930993664
mapped_file 306728960
pgpgin 406632648
pgpgout 403355412
swap 0
pgfault 728281223
pgmajfault 1724
inactive_anon 46608384
active_anon 1884520448
inactive_file 7003344896
active_file 4489052160
unevictable 32768
hierarchical_memory_limit 9223372036854775807
hierarchical_memsw_limit 9223372036854775807
total_cache 11492564992
total_rss 1930993664
total_mapped_file 306728960
total_pgpgin 406632648
total_pgpgout 403355412
total_swap 0
total_pgfault 728281223
total_pgmajfault 1724
total_inactive_anon 46608384
total_active_anon 1884520448
total_inactive_file 7003344896
total_active_file 4489052160
total_unevictable 32768
```

The first half (without the `total_` prefix) contains statistics relevant
to the processes within the cgroup, excluding sub-cgroups. The second half
(with the `total_` prefix) includes sub-cgroups as well.

Some metrics are "gauges", i.e. values that can increase or decrease
(e.g. `swap`, the amount of swap space used by the members of the cgroup).
Some others are "counters", i.e. values that can only go up, because
they represent occurrences of a specific event (e.g. `pgfault`, which
indicates the number of page faults which happened since the creation
of the cgroup; this number can never decrease).

Let's see what those metrics stand for. All memory amounts are in bytes
(except for event counters).

- **cache** is the amount of memory used by the processes of this
  control group that can be associated precisely with a block on a
  block device. When you read and write
  files from and to disk, this amount will increase. This will be the
  case if you use "conventional" I/O (`open`, `read`, `write` syscalls)
  as well as mapped files (with `mmap`). It also accounts for the
  memory used by `tmpfs` mounts. I don't know exactly why; it might
  be because `tmpfs` filesystems work directly with the page cache.
  
- **rss** is the amount of memory that *doesn't*
  correspond to anything on disk: stacks, heaps, and anonymous memory
  maps.

- **mapped_file** indicates the amount of memory mapped by the processes
  in the control group. In my humble opinion, it doesn't give you
  an information about *how much* memory is used; it rather tells you
  *how* it is used. 

- **pgpgin** and **pgpgout** are a bit tricky. If you are used to `vmstat`,
  you might think that they indicate the number of times that a page
  had to be read and written (respectively) by a process of the cgroup,
  and that they should reflect both file I/O and swap activity.
  Wrong! In fact, they correspond to *charging events*. Each time
  a page is "charged" (=added to the accounting) to a cgroup,
  **pgpgin** increases. When a page is "uncharged" (=no longer "billed"
  to a cgroup), **pgpgout** increases.

- **pgfault** and **pgmajfault** indicate the number of times that
  a process of the cgroup triggered a "page fault" and a "major fault",
  respectively. A page fault happens when a process accesses a part
  of its virtual memory space which is inexistent or protected.
  The former can happen if the process is buggy and tries to access
  an invalid address (it will then be sent a `SIGSEGV` signal,
  typically killing it with the famous `Segmentation fault` message).
  The latter can happen when the process reads from a memory
  zone which has been swapped out, or which corresponds to
  a mapped file: in that case, the kernel will load the page from
  disk, and let the CPU complete the memory access. It can also
  happen when the process writes to a copy-on-write memory zone:
  likewise, the kernel will preempt the process, duplicate the
  memory page, and resume the write operation on the process'
  own copy of the page. "Major" faults happen when the kernel
  actually has to read the data from disk. When it just has to
  duplicate an existing page, or allocate an empty page, it's a
  regular (or "minor") fault.

- **swap** is (as expected) the amount of swap currently used by
  the processes in this cgroup.

- **active_anon** and **inactive_anon** is the amount of *anonymous*
  memory that has been identified has respectively *active* and
  *inactive* by the kernel. "Anonymous" memory is the memory that
  is *not* linked to disk pages. In other words, that's the equivalent
  of the **rss** counter described above. In fact, the very definition
  of the **rss** counter is **active_anon**+**inactive_anon**-**tmpfs**
  (where **tmpfs** is the amount of memory used up by `tmpfs`
  filesystems mounted by this control group). Now, what's the difference
  between "active" and "inactive"? Pages are initially "active";
  and at regular intervals, the kernel sweeps over the memory,
  and tags some pages as "inactive". Whenever they are accessed again,
  they are immediately retagged "active". When the kernel is almost
  out of memory, and time comes to swap out to disk, the kernel
  will swap "inactive" pages.

- Likewise, the **cache** memory is broken down into **active_file**
  and **inactive_file**. The exact formula is
  **cache**=**active_file**+**inactive_file**+**tmpfs**.
  The exact rules used by the kernel to move memory pages between
  active and inactive sets are different from the ones used
  for anonymous memory, but the general principle is the same.
  Note that when the kernel needs to reclaim memory, it is cheaper
  to reclaim a clean (=non modified) page from this pool, since
  it can be reclaimed immediately (while anonymous pages and
  dirty/modified pages have to be written to disk first).

- **unevictable** is the amount of memory that cannot be reclaimed;
  generally, it will account for memory that has been "locked"
  with `mlock`. It is often used by crypto frameworks to make
  sure that secret keys and other sensitive material never gets
  swapped out to disk.
  
- Last but not least, the **memory** and **memsw** limits are not
  really metrics, but a reminder of the limits applied to this
  cgroup. The first one indicates the maximum amount of physical
  memory that can be used by the processes of this control group;
  the second one indicates the maximum amount of RAM+swap.
  
Accounting for memory in the page cache is very complex. If two
processes in different control groups both read the same file
(ultimately relying on the same blocks on disk), the corresponding
memory charge will be split between the control groups. It's nice,
but it also means that when a cgroup is terminated, it could
increase the memory usage of another cgroup, because they are
not splitting the cost anymore for those memory pages.


### CPU metrics

Now that we've covered memory metrics, everything else will
look very simple in comparison. CPU metrics will be found in
the `cpuacct` controller.

For each container, you will find a pseudo-file `cpuacct.stat`,
containing the CPU usage accumulated by the processes of the
container, broken down between `user` and `system` time. If
you're not familiar with the distinction, `user` is the time
during which the processes were in direct control of the CPU
(i.e. executing process code), and `system` is the time during
which the CPU was executing system calls on behalf of those
processes.

Those times are expressed in ticks of 1/100th of second.
(Actually, they are expressed in "user jiffies". There are
`USER_HZ` *"jiffies"* per second, and on x86 systems, `USER_HZ`
is 100. This used to map exactly to the number of scheduler
"ticks" per second; but with the advent of higher frequency
scheduling, as well as [tickless kernels],
the number of
kernel ticks wasn't relevant anymore. It stuck around anyway,
mainly for legacy and compatibility reasons.)


### Block I/O metrics

Block I/O is accounted in the `blkio` controller. Different
metrics are scattered across different files. While you can
find in-depth details in the [blkio-controller]
file in the kernel documentation, here is a short list of the
most relevant ones:

- **blkio.sectors** contains the number of 512-bytes sectors
  read and written by the processes member of the cgroup,
  device by device. Reads and writes are merged in a
  single counter.

- **blkio.io_service_bytes** indicates the number of bytes
  read and written by the cgroup. It has 4 counters per
  device, because for each device, it differentiates between
  synchronous vs. asynchronous I/O, and reads vs. writes.

- **blkio.io_serviced** is similar, but instead of showing
  byte counters, it will show the number of I/O operations
  performed, regardless of their size. It also has 4 counters
  per device.

- **blkio.io_queued** indicates the number of I/O operations
  currently queued for this cgroup. In other words, if the cgroup
  isn't doing any I/O, this will be zero. Note that the opposite
  is not true. In other words, if there is no I/O queued, it does
  not mean that the cgroup is idle (I/O-wise). It could be doing
  purely synchronous reads on an otherwise quiescent device, which
  is therefore able to handle them immediately, without queuing.
  Also, while it is helpful to figure out which cgroup is putting
  stress on the I/O subsystem, keep in mind that is is a relative
  quantity. Even if a process group does not perform more I/O,
  its queue size can increase just because the device load increases
  because of other devices.

For each file, there is a `_recursive` variant, that aggregates
the metrics of the control group and all its sub-cgroups.

Also, it's worth mentioning that in most cases, if the processes
of a control group have not done any I/O on a given block device,
the block device will not appear in the pseudo-files. In other
words, you have to be careful each time you parse one of those
files, because new entries might have appeared since the previous
time.


## Collecting network metrics

Interestingly, network metrics are not exposed directly by
control groups. There is a good explanation for that: network
interfaces exist within the context of *network namespaces*.
The kernel could probably accumulate metrics about packets
and bytes sent and received by a group of processes, but
those metrics wouldn't be very useful. You want (at least!)
per-interface metrics (because traffic happening on the local
`lo` interface doesn't really count). But since processes
in a single cgroup can belong to multiple network namespaces,
those metrics would be harder to interpret: multiple network
namespaces means multiple `lo` interfaces, potentially
multiple `eth0` interfaces, etc.; so this is why there is no
easy way to gather network metrics with control groups.

So what shall we do? Well, we have multiple options.


### Iptables

When people think about `iptables`, they usually think about
firewalling, and maybe NAT scenarios. But `iptables` (or rather,
the `netfilter` framework for which `iptables` is just an interface)
can also do some serious accounting.

For instance, you can setup a rule to account for the outbound
HTTP traffic on a web server:

    iptables -I OUTPUT -p tcp --sport 80

There is no `-j` or `-g` flag, so the rule will just count matched
packets and go to the following rule.

Later, you can check the values of the counters, with:

    iptables -nxvL OUTPUT

(Technically, `-n` is not required, but it will prevent iptables
from doing DNS reverse lookups, which are probably useless in
this scenario.)

Counters include packets and bytes. If you want to setup metrics
for container traffic like this, you could execute a `for` loop
to add two `iptables` rules per container IP address (one in each
direction), in the `FORWARD` chain. This will only meter traffic
going through the NAT layer; you will also have to add traffic
going through the userland proxy.

Then, you will need to check those counters on a regular basis.
If you happen to use [collectd],
there is a nice plugin to automate iptables counters collection.


### Interface-level counters

Since each container has a virtual Ethernet interface, you might
want to check directly the TX and RX counters of this interface.
However, this is not as easy as it sounds. If you use Docker
(as of current version 0.6) or `lxc-start`, then you will notice that
each container is associated to a virtual Ethernet interface in
your host, with a name like `vethKk8Zqi`. Figuring out
which interface corresponds to which container is, unfortunately,
difficult. (If you know an easy way, let me know.)

In the long run, Docker will probably take over the setup of
those virtual interfaces. It will keep track of their names,
and make sure that it can easily associate containers with their
respective interfaces.

But for now, the best way is to check the metrics *from within
the containers*. I'm not talking about running a special agent
in the container, or anything like that. We are going to run
an executable from the host environment, but within the network
namespace of a container.


#### ip-netns magic

To do that, we will use the `ip netns exec` command. This
command will let you execute any program (present in the
host system) within any network namespace visible to
the current process. This means that your host will be
able to enter the network namespace of your containers,
but your containers won't be able to access the host,
nor their sibling containers. Containers will be able to
"see" and affect their sub-containers, though.

The exact format of the command is:

    ip netns exec <nsname> <command...>

For instance:

    ip netns exec mycontainer netstat -i

How does the naming system work? How does `ip netns` find 
`mycontainer`? Answer: by using the namespaces
pseudo-files. Each process belongs to one network namespace,
one PID namespace, one `mnt` namespace, etc.; and those
namespaces are materialized under `/proc/<pid>/ns/`.
For instance, the network namespace of PID 42 is materialized
by the pseudo-file `/proc/42/ns/net`.

When you run `ip netns exec mycontainer ...`, it expects
`/var/run/netns/mycontainer` to be one of those pseudo-files.
(Symlinks are accepted.)

In other words, to execute a command within the network
namespace of a container, we need to:

- find out the PID of any process within the container that
  we want to investigate;
- create a symlink from `/var/run/netns/<somename>` to
  `/proc/<thepid>/ns/net`;
- execute `ip netns exec <somename> ...`.

Now, we need to figure out a way to find the PID of a
process (any process!) running in the container that we
want to investigate. This is actually very easy. You have
to locate one of the control groups corresponding to the
container. We explained how to locate those cgroups in
the beginning of this post, so we won't cover that again.

On my machine, a control group will typically be located in
`/sys/fs/cgroup/devices/lxc/<containerid>`. Within that
directory, you will find a pseudo-file called `tasks`.
It contains the list of the PIDs that are in the control group,
i.e., in the container. We can take any of them; so the first one
will do.

Putting everything together, if the "short ID" of a container
is held in the environment variable `$CID`, here is a small
shell snippet to put everything together:

```bash
TASKS=/sys/fs/cgroup/devices/$CID*/tasks
PID=$(head -n 1 $TASKS)
mkdir -p /var/run/netns
ln -sf /proc/$PID/ns/net /var/run/netns/$CID
ip netns exec $CID netstat -i
```

The same mechanism is used in [Pipework] to setup network
interfaces within containers *from outside* the containers.


#### Tips for high-performance metric collection

Note that running a new process each time you want to update
metrics is (relatively) expensive. If you want to collect metrics
at high resolutions, and/or over a large number of containers
(think 1000 containers on a single host), you do not want to
fork a new process each time.

Here is how to collect metrics from a single process.
You will have to write your metric collector in C (or any language
that lets you do low-level system calls).
You need to use a special system call, `setns()`, which lets the
current process enter any arbitrary namespace. It requires,
however, an open file descriptor to the namespace pseudo-file
(remember: that's the pseudo-file in `/proc/<pid>/ns/net`).

However, there is a catch: you must not keep this file descriptor
open. If you do, when the last process of the control group
exits, the namespace will not be destroyed, and its network
resources (like the virtual interface of the container) will stay
around for ever (or until you close that file descriptor).

The right approach would be to keep track of the first PID
of each container, and re-open the namespace pseudo-file
each time.


## Collecting metrics when a container exits

Sometimes, you do not care about real time metric collection,
but when a container exits, you want to know how much CPU, memory,
etc. it has used. 

The current implementation of Docker (as of 0.6) makes this
particularly challenging, because it relies on `lxc-start`, and when
a container stops, `lxc-start` carefully cleans up behind it.
If you really want to collect the metrics anyway, here is how. 

For each container, start a collection process,
and move it to the control groups that
you want to monitor by writing its PID to the `tasks` file of the
cgroup. The collection process should periodically re-read the `tasks`
file to check if it's the last process of the control group.
(If you also want to collect network statistics as explained
in the previous section, you should also move the process to
the appropriate network namespace.)

When the container exits, `lxc-start` will try to delete the control
groups. It will fail, since the control group is still in use;
but that's fine. You process should now detect that it is the only
one remaining in the group. Now is the right time to collect all the
metrics you need!

Finally, your process should move itself back to the root
control group, and remove the container control group. To remove a
control group, just `rmdir` its directory. It's counter-intuitive
to `rmdir` a directory as it still contains files; but remember that
this is a pseudo-filesystem, so usual rules don't apply. After the
cleanup is done, the collection process can exit safely.

As you can see, collecting metrics when a container exits can be tricky;
for this reason, it is usually easier to collect metrics at regular
intervals (e.g. every minute) and rely on that instead.


## Wrapping it up

To recap, we covered:

- how to locate the control groups for containers;
- reading and interpreting compute metrics for containers;
- different ways to obtain network metrics for containers;
- a technique to gather overall metrics when a container exits.

As we have seen, metrics collection is not insanely difficult,
but still involves many complicated steps, with special cases like those for the network subsystem. Docker will take care of this,
or at least expose hooks to make it more straightforward.
It is one of the reasons why we repeat over and over "Docker
is not production ready yet": it's fine to skip metrics for
development, continuous testing, or staging environments,
but it's definitely *not fine* to run production services
without metrics!

Last but not least, note that even with all that information,
you will still need a storage and graphing system for those metrics.
There are many such systems out there. If you want something that you can
deploy on your own, you can check e.g. [collectd] or [Graphite].
There are also "-as-a-Service" offerings. Those services will store
your metrics and let you query them in various ways, for a given price.
Some examples include [Librato], [AWS CloudWatch],
[New Relic Server Monitoring], and many more.


## Acknowledgements

This post was initally published on the [Docker blog].

I'm indebted to [Andrew Rothfusz] for proofreading this article.
If any mistake or typo remains, I take full responsibility for them :-)


[Andrew Rothfusz]: https://github.com/metalivedev
[control groups]: https://www.kernel.org/doc/Documentation/cgroups/cgroups.txt
[blkio-controller]: https://www.kernel.org/doc/Documentation/cgroups/blkio-controller.txt
[collectd]: http://collectd.org/
[Docker blog]: http://blog.docker.io/2013/10/gathering-lxc-docker-containers-metrics/
[Graphite]: http://graphite.wikidot.com/
[jiffies]: http://en.wikipedia.org/wiki/Jiffy_(time)
[Librato]: https://metrics.librato.com/
[New Relic Server Monitoring]: http://newrelic.com/server-monitoring
[AWS CloudWatch]: http://aws.amazon.com/cloudwatch/
[Pipework]: https://github.com/jpetazzo/pipework
[tickless kernels]: http://lwn.net/Articles/549580/
