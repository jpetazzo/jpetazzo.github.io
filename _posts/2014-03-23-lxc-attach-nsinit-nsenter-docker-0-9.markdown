---
layout: post
title: Attaching to a container with Docker 0.9 and libcontainer
tags: docker
---

If you upgraded your Docker installation to 0.9, you are now
using [libcontainer] to run your containers. And if you were
using `lxc-attach`, you probably noticed that it doesn't work
anymore. Here are two ways to recover the "attach" feature
with Docker containers.


## What happened?

First, let's explain exactly what's involved here. Before 0.9,
Docker was using the LXC userland tools to start containers.
It means that `docker run …` eventually translated to a call to
`lxc-start`. As such, Docker containers could be managed with
the LXC userland tools, including `lxc-attach` to obtain a shell
within an existing container. This is a very convenient feature,
because you can drop into a container without having to run
a special server process within the container. 

`lxc-attach` relies on the fact that each container created with
`lxc-start` listens on a specific socket: by default, an abstract
socket named `/var/lib/lxc/<container_name>/command`. It uses
that socket to infer the PID of the container, and then uses
the `setns()` syscall to attach a new process to the namespaces
used by the container.

Docker 0.9 ships with the "native" execution driver, which uses
libcontainer instead of the LXC userland tools. And guess what,
libcontainer doesn't create that abstract socket, so `lxc-attach`
is confused and can't locate the container.

There are (at least) three solutions:

- use `nsenter`, a little Linux tool to fiddle with namespaces
  and enter them (as you could guess from the name!);
- use `nsinit`, a tool that comes with libcontainer;
- revert to the LXC driver (if you can't install `nsenter` or
  `nsinit`).


## Use `nsenter`

In most distros, `nsenter` is in the `util-linux` package. It ships
after version 2.23. Unfortunately, Debian and Ubuntu still ship with
util-linux 2.20 as of March 2014; so you will have to compile it
yourself:

```
cd /tmp
curl https://www.kernel.org/pub/linux/utils/util-linux/v2.24/util-linux-2.24.tar.gz | tar -zxf-
cd util-linux-2.24
./configure --without-ncurses
make nsenter
cp nsenter /usr/local/bin
```

(You might have to adjust the `configure` line a little bit.)

Now, find the PID of the first process of the container (actually,
any PID will do, but this is just easier and safer):

    PID=$(docker inspect --format '{{.State.Pid}}' my_container_id)

Then, enter like this:

    nsenter --target $PID --mount --uts --ipc --net --pid

Voilà, you are now in the container!

`nsenter` does not drop capabilities; so the shell started by `nsenter`
can do more stuff (and more harm!) than a normal process running within
the container.

Note: when looking for details about `nsenter`, I realized that
[Sebastien Han] already posted a very similar recipe. If you want
to use nsenter before version 0.9, his recipe works best (since
Docker pre-0.9 doesn't have `.State.Pid`).


## Use `nsinit`

According to [Michael Crosby], it is even better to use `nsinit`.
And he's a core maintainer of Docker, and primary author of libcontainer;
so you bet he knows what he's talking about ☺

To install `nsinit`, you need a Go development environment.
(On Debian/Ubuntu, `apt-get install golang-go` might be sufficient.)

Then, assuming that your `GOPATH` etc. is set correctly, all you need is:

```
go install github.com/dotcloud/docker/pkg/libcontainer/nsinit/nsinit
```

Then, you need to go to the container configuration directory.
Where's that? It's in `/var/lib/docker/execdriver/native/<container_id>/`.
Find the short ID of your container with `docker ps`, then go to the
right directory (you will need root access, since `/var/lib/docker` is
readable only by root).

Then, once in that directory, just run `nsinit exec bash`. That's all.

You can check this [Asciinema demo] to see it in action!


## Revert to the LXC driver

If you can't compile neither `nsenter` nor `nsinit`, well, your last
option is to revert Docker to use the LXC driver.

First, stop your Docker daemon. Then edit the daemon start options
(on Debian/Ubuntu, edit `/etc/default/docker` and fine the line with
`DOCKER_OPTS`). Add `-e lxc`. Restart Docker. Done. You can now use
`lxc-attach` again, but each morning, when you'll see your face in
the mirror, you will have to remember that this is the face of 
someone who is missing all the goodness of libcontainer!


[libcontainer]: http://blog.docker.io/2014/03/docker-0-9-introducing-execution-drivers-and-libcontainer/
[Sebastien Han]: http://www.sebastien-han.fr/blog/2014/01/27/access-a-container-without-ssh/
[Michael Crosby]: https://twitter.com/crosbymichael
[Asciinema demo]: https://asciinema.org/a/8090
