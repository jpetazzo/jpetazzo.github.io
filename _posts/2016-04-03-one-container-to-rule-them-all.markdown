---
layout: post
title: One container to rule them all
---

A while ago, I wrote about how to [bind-mount the Docker control socket](
{% post_url 2015-09-03-do-not-use-docker-in-docker-for-ci %}) instead
of running Docker-in-Docker. This is a huge win for CI use-cases, and
many others. Here I want to talk about a more generic scenario:
controlling any Docker setup (local or remote Engine, but also Swarm
clusters) from a container, and the benefits that it brings us.


## Bind-mounting the control socket

If you have never done this before, I invite you to try the following
command (on a Linux machine running a local Docker Engine, or if you
are one of the lucky fews who have access to Docker Mac when this
article is published):

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock \
           -ti docker docker ps
```

This will execute `docker ps` in a container (using the `docker`
official image), and it will display the containers running on your
local Docker Engine. There will be at least the container running
`docker ps` itself, and possibly other containers that are running
at that moment.

This gives us a way to control the Docker Engine *from within
a container*. This is particularly convenient when you want to
create containers from within a container, without running
Docker-in-Docker.

However, this only works if you are connecting to Docker using
a local UNIX socket. In other words, it doesn't work if you
are using:

- a remote Docker Engine (with or without TLS authentication),
- a local boot2docker VM,
- a Swarm cluster.

If you are using a remote Engine *without* TLS authentication,
the only thing you need to do is to set the `DOCKER_HOST`
environment variable. Then all standard tools (like the Docker
CLI and Docker Compose) will automatically detect this variable
and use it to contact the Engine. But if you are using
TLS authentication (and you definitely should!) things
are a bit more complex.

I want to give you a generic method to connect to *any* Docker
API endpoint *from within a container*, regardless of its location
(local or remote), even if it's using TLS, even if it's actually
a Swarm cluster instead of a single Engine.


## Let's look at our environment

To connect to remote Docker API endpoints using TLS, we need a bit more
than the `DOCKER_HOST` environment variable. First of all, we need
to tell our local Docker client to use TLS, by setting the `DOCKER_TLS_VERIFY`
environment variable. We also need to provide the client with:

- a private key,
- a certificate (used to prove our identity to the remote server),
- a root certificate (used to check the identity of the remote server).

Those elements will be stored in three files in [PEM] format:

- key.pem,
- cert.pem,
- ca.pem.

By default, the client looks for those files in the `~/.docker` directory,
but this can be changed by setting the `DOCKER_CERT_PATH` environment
variable to another directory.

If you are using Docker Machine, you can easily check what those variables
look like with the `env` command; e.g. if you have a Docker Machine named
`node1`:

```bash
$ docker-machine env node1
export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://11.22.33.44:2376"
export DOCKER_CERT_PATH="/home/docker/.docker/machine/machines/node1"
export DOCKER_MACHINE_NAME="node1"
# Run this command to configure your shell:
# eval $(docker-machine env node1)
```

If we want to connect to this Docker Engine from within a container, we
just need to set those environment variables, and make the three PEM
files available within the container.


## Transporting TLS material and settings

Of course, we could manually copy-paste the environment variables and
the three PEM files from our host to our container. But we are going
to automate the process, and store everything we need in a data container
named `dockercontrol`. Assuming that our environment is currently
setup to talk to some remote Docker API endpoint secured with TLS,
we can run the following command:

```bash
$ tar -C $DOCKER_CERT_PATH -cf- ca.pem cert.pem key.pem |
  docker run --name dockercontrol -i -v /docker busybox \
  sh -c "tar -C /docker -xf-
         echo export DOCKER_HOST=$DOCKER_HOST >>/docker/env
         echo export DOCKER_TLS_VERIFY=1 >>/docker/env
         echo export DOCKER_CERT_PATH=/docker >>/docker/env"
```

This will create a tar archive locally, containing the three PEM files;
then it will stream this archive to a container which will unpack it
on the fly; and finally we create an `env` file that can be sourced
later to restore the environment variables.

Now, when we need to talk to our Docker API endpoint from a container,
all we have to do is to start that container with
`--volumes-from dockercontrol`, and `source /docker/env`:

```bash
$ docker run --rm --volumes-from dockercontrol docker \
  sh -c "source /docker/env; docker ps"
```

If you want a totally transparent operation (i.e. you don't want
to change the container so that it sources `/docker/env`) you can
also read that file on your host, and pass down the environment
variables to your containers.


## Data containers vs. named volumes

You might be wondering why I'm using an old-fashioned [data container]
instead of creating a proper [named volume[ (with `docker volume create`).
This would indeed be more
"Dockerish" but wouldn't work (yet) with Swarm; e.g. when
doing `docker run -v dockercontrol:/docker …` we would have
to add an affinity constraint to make sure that the container
is created on the host that has the `dockercontrol` volume.
I think it's simpler to use a data container for now.


## Putting everything together

I wrote a little shell script to automate the whole process;
it's available on [jpetazzo/dctrl] on GitHub.

It lets you run:

```bash
$ dctrl purple
```

This will create a data container named `purple`, holding
the information necessary to connect to the current Docker API
endpoint.

Then, if you need to run a container that has access to this
Docker API endpoint, you can do:

```bash
$ eval \$(docker run --rm --volumes-from $CONTROL alpine
          sed 's/DOCKER_/DOCKERCONTROL_/' /docker/env)"
$ docker run --volumes-from $CONTROL \
  -e DOCKER_HOST=\$DOCKERCONTROL_HOST \
  -e DOCKER_TLS_VERIFY=\$DOCKERCONTROL_TLS_VERIFY \
  -e DOCKER_CERT_PATH=\$DOCKERCONTROL_CERT_PATH \
  ...
```


## What can we use this for?

This allows us to create containers from a container, even when
running on e.g. a Swarm cluster. (I initially thought about writing
this blog post when 3 different persons, the same week, asked
me "how can I bind-mount the Docker socket when the Docker Engine
is not local, but on a remote host?")

But this is also very useful in the general case when you need
a container to be able to interact with your overall Docker setup;
e.g. to setup or reconfigure a load balancer. See for instance
[dockercloud-haproxy], which accesses the Docker Events API
to notice when backends are added to a service, and dynamically
update load balancer configuration accordingly.

Another example would be the implementation of a replication
controller in a container. This container would be given
e.g. a Compose file and a set of scaling parameters (the number
of desired intances for each service). It would bring up
the application described by the Compose file, scale it
according to the scaling parameters, and watch the Docker Events
API to adjust the number of containers should any node
go down during the lifecycle of the application.
(That container would be started with a rescheduling policy,
to be automatically redeployed by Swarm if its own node
goes down.)

Generally speaking, any kind of application that needs
access to the Docker API would benefit from this as soon
as you want to be able to run it seamlessly in a container.


## Power to the people

This takes me to one of my favorite features of Docker Swarm:
the fact that it uses the same API as the Docker Engine.

This means that as a developer, when I build my application
on my local machine with a single Docker Engine, I leverage
the full API that will be available on a Swarm cluster:

- if I need to partition my app across [multiple networks],
  I can do it on a single node with the default `bridge` driver,
  and when I deploy on a Swarm cluster, everything will work
  exactly the same way, thanks to the `overlay` driver
  (or whatever network plugin has been deployed by my ops team);
- if I need to use persistence and volumes, same story:
  I will use the default local driver in my environment,
  and if I'm running on a cluster with a volume plugin like
  [Flocker] or [PortWorx], it will automatically achieve
  reliable persistence without changing anything on my side;
- if I want to automatically scale up and down a background
  worker depending on the backlog size of a message queue,
  I can develop and test this locally, because the API
  used to scale (and gather metrics) will be the same in
  my local environment and the production one.

This last example is particularly powerful. If you are developing
an app intended to run in the public cloud, and want to use
auto-scaling, you won't be able to test the auto-scaling behavior
locally - unless your cloud provider gives you the option
of installing a fully functional cloud instance locally,
on your development laptop. With Docker, the fully functional
cloud instance is the Docker Engine that you're already using
to power your containers.

*If you have some other creative scenario involving
controlling the Docker API from within a container, let me know!*

**Want to learn more about Docker?** I will deliver two
Docker workshops next month (May 2016) in Austin, Texas:
an [intro-level workshop] and an [advanced orchestration
workshop] using Compose, Swarm, and Machine to build,
ship, and run distributed applications. If you want to
attend, you can get 20% off the conference and workshop
prices using the code PETAZZONI20. I will also deliver
those workshops at other conferences in Europe and the US,
so if you're interested, let me know!


[PEM]: https://en.wikipedia.org/wiki/Privacy-enhanced_Electronic_Mail
[named volume]: https://docs.docker.com/engine/reference/commandline/volume_create/
[data container]: https://docs.docker.com/engine/userguide/containers/dockervolumes/
[jpetazzo/dctrl]: https://github.com/jpetazzo/dctrl
[dockercloud-haproxy]: https://github.com/docker/dockercloud-haproxy
[multiple networks]: https://docs.docker.com/compose/networking/
[Flocker]: https://clusterhq.com/flocker/introduction/
[PortWorx]: http://portworx.com/
[intro-level workshop]: http://conferences.oreilly.com/oscon/open-source-us/public/schedule/detail/50042
[advanced orchestration workshop]: http://conferences.oreilly.com/oscon/open-source-us/public/schedule/detail/49039
