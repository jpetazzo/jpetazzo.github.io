---
layout: post
title: Using Docker-in-Docker for your CI or testing environment? Think twice.
---

The primary purpose of Docker-in-Docker was to help with the development
of Docker itself. Many people use it to run CI (e.g. with Jenkins),
which seems fine at first, but they run into many "interesting" problems
that can be avoided by bind-mounting the Docker socket into your
Jenkins container instead.

Let's see what this means. If you want the short solution without the details,
just scroll to the bottom of this article. ☺

*Update (July 2020) : when I wrote this blog post
in 2015, the only way to run Docker-in-Docker was to use the -privileged
flag in Docker. Today, the landscape is very different. Container
security and sandboxing advanced very significantly, with e.g.
[rootless containers] and tools like [sysbox]. The latter lets
you run Docker-in-Docker without the -privileged flag, and even
comes with optimizations for some specific scenarios, like running
multiple nodes of a Kubernetes cluster as ordinary containers.
This article has been updated to reflect that!*


## Docker-in-Docker: the good

More than two years ago, I contributed the [-privileged flag in Docker]
and wrote the [first version of dind]. The goal was to help the core team
to work faster on Docker development. Before Docker-in-Docker, the
typical development cycle was:

- hackity hack
- build
- stop the currently running Docker daemon
- run the new Docker daemon
- test
- repeat

And if you wanted to a nice, reproducible build (i.e. in a container),
it was a bit more convoluted:

- hackity hack
- make sure that a workable version of Docker is running
- build new Docker with the old Docker
- stop Docker daemon
- run the new Docker daemon
- test
- stop the new Docker daemon
- repeat

With the advent of Docker-in-Docker, this was simplified to:

- hackity hack
- build+run in one step
- repeat

Much better, right?


## Docker-in-Docker: the bad

However, contrary to popular belief, Docker-in-Docker is not 100% made
of sparkles, ponies, and unicorns. What I mean here is that there are
a few issues to be aware of.

One is about LSM (Linux Security Modules)
like AppArmor and SELinux: when starting a container, the "inner Docker"
might try to apply security profiles that will conflict or confuse
the "outer Docker." This was actually the hardest problem to solve
when trying to merge the original implementation of the `-privileged`
flag. My changes worked (and all tests would pass) on my Debian
machine and Ubuntu test VMs, but it would crash and burn on
[Michael Crosby]'s machine (which was Fedora if I remember well).
I can't remember the exact cause of the issue, but it might have been
because Mike is a wise person who runs with `SELINUX=enforce`
(I was using AppArmor) and my changes didn't take SELinux profiles
into account.


## Docker-in-Docker: the ugly

The second issue is linked to storage drivers. When you run Docker
in Docker, the outer Docker runs on top of a normal filesystem (EXT4,
BTRFS, what have you) but the inner Docker runs on top of a copy-on-write
system (AUFS, BTRFS, Device Mapper, etc., depending on what the outer
Docker is setup to use). There are many combinations that won't work.
For instance, you cannot run AUFS on top of AUFS. If you run BTRFS
on top of BTRFS, it should work at first, but once you have nested
subvolumes, removing the parent subvolume will fail. Device Mapper
is not namespaced, so if multiple instances of Docker use it on the
same machine, they will all be able to see (and affect) each other's
image and container backing devices. No bueno.

There are workarounds for many of those issues; for instance,
if you want to use AUFS in the inner Docker, just promote
`/var/lib/docker` to be a volume and you'll be fine.
Docker added some basic namespacing to Device Mapper target
names, so that if multiple invocations of Docker run on the same
machine, they won't step on each other.

Yet, the setup is not entirely straightforward, as you can
[see](https://github.com/jpetazzo/dind/issues/86)
[from](https://github.com/jpetazzo/dind/issues/66)
[those](https://github.com/jpetazzo/dind/issues/78)
[issues](https://github.com/jpetazzo/dind/issues/19)
on the `dind` repository on GitHub.


## Docker-in-Docker: it gets worse

And what about the build cache? That one can get pretty tricky too.
People often ask me, "I'm running Docker-in-Docker; how can I use
the images located on my host, rather than pulling everything again
in my inner Docker?"

Some adventurous folks have tried to bind-mount `/var/lib/docker`
from the host into the Docker-in-Docker container. Sometimes they
share `/var/lib/docker` with multiple containers.

![Sterling Archer advises you to not share /var/lib/docker, thx](
/assets/archer.jpg)

The Docker daemon was explicitly designed to have exclusive
access to `/var/lib/docker`. Nothing else should touch, poke,
or tickle any of the Docker files hidden there.

Why is that? It's one of the hard learned lessons from the
dotCloud days. The dotCloud container engine worked by having
multiple processes accessing `/var/lib/dotcloud` simultaneously.
Clever tricks like atomic file replacement (instead of in-place
editing), peppering the code with advisory and mandatory locking,
and other experiments with safe-ish systems like SQLite and BDB
only got us so far; and when we refactored our container engine
(which eventually became Docker) one of the big design decisions
was to gather all the container operations under a single daemon
and be done with all that concurrent access nonsense.

(Don't get me wrong: it's totally possible to do something
nice and reliable and fast involving multiple processes and
state-of-the-art concurrency management; but we think that
it's simpler, as well as easier to write and to maintain,
to go with the single actor model of Docker.)

This means that if you share your `/var/lib/docker` directory
between multiple Docker instances, you're gonna have a bad time.
Of course, it might work, especially during early testing.
"Look ma, I can `docker run ubuntu`!" But try to do something
more involved (pull the same image from two different instances...)
and watch the world burn.

This means that if your CI system does builds and rebuilds,
each time you'll restart your Docker-in-Docker container, you
might be nuking its cache. That's really not cool.


## Docker-in-Docker: and then it gets better

You certainly have heard some variant of that famous quote by
Mark Twain: "They didn't know it was impossible, so they did it."

Many folks tried to run Docker-in-Docker safely.
A few years ago, I had modest success with user namespaces and
some really nasty hacks (including mocking the cgroups pseudo-fs
structure over tmpfs mounts so that the container runtime wouldn't
complain too much; fun times) but it appeared that a *clean*
solution would be a major endeavor.

That clean solution exists now: it's called [sysbox].
Sysbox is an OCI runtime that can be used instead of,
or in addition to, runc. It makes it possible to run
"system containers" that would typically require the
privileged flag, *without* the privileged flag; and
provides adequate isolation between these containers,
as well as between these containers and their host.

Sysbox also provides optimizations to run containers-in-containers.
Specifically, when running multiple instances of Docker
side by side, it is possible to "seed" them
with a shared set of images. This saves both a lot of
disk space and a lot of time, and I think this makes a huge
difference when running e.g. Kubernetes nodes in containers.

(Running Kubernetes nodes in containers can be particularly
useful for CI/CD, when you want to deploy a Kubernetes
staging app or run tests in its own cluster, without
the infrastructure cost and time overhead of deploying
a full cluster on dedicated machines.)

Long story short: if your use case *really absolutely*
mandates Docker-in-Docker, have a look at [sysbox],
it might be what you need.


## The socket solution

Let's take a step back here. Do you really want Docker-in-Docker?
Or do you just want to be able to run Docker (specifically: build,
run, sometimes push containers and images) from your CI system,
while this CI system itself is in a container?

I'm going to bet that most people want the latter. All you want is
a solution so that your CI system like Jenkins can start containers.

And the simplest way is to just expose the Docker socket to your
CI container, by bind-mounting it with the `-v` flag.

Simply put, when you start your CI container (Jenkins or other),
instead of hacking something together with Docker-in-Docker,
start it with:

```
docker run -v /var/run/docker.sock:/var/run/docker.sock ...
```

Now this container will have access to the Docker socket, and will therefore
be able to start containers. Except that instead of starting "child" containers,
it will start "sibling" containers.

Try it out, using the `docker` official image (which contains the Docker
binary):

```
docker run -v /var/run/docker.sock:/var/run/docker.sock \
           -ti docker
```

This looks like Docker-in-Docker, feels like Docker-in-Docker, but it's not
Docker-in-Docker: when this container will create more containers, those
containers will be created in the top-level Docker. You will not experience
nesting side effects, and the build cache will be shared across multiple
invocations.

⚠️ Former versions of this post advised to bind-mount the `docker` binary
from the host to the container. **This is not reliable anymore,** because
the Docker Engine is no longer distributed as (almost) static libraries.

If you want to use e.g. Docker from your Jenkins CI system, you have
multiple options:

- installing the Docker CLI using your base image's packaging system
  (i.e. if your image is based on Debian, use .deb packages),
- using the Docker API.


[first version of dind]: https://github.com/jpetazzo/dind/commit/bfbe19c0eec634f66c9f8bac53c6b7c7e0fdb063
[-privileged flag in Docker]: https://github.com/docker/docker/commit/280901e5fbd0c2dabd14d7a9b69a073f6e8f87e4
[Michael Crosby]: https://twitter.com/crosbymichael
[Nestybox]: https://www.nestybox.com/
[rootless containers]: https://rootlesscontaine.rs/
[sysbox]: https://github.com/nestybox/sysbox-external
