---
layout: post
title: "Multiple Docker containers logging to a single syslog"
---

This is a simple recipe showing how to run syslog in one container,
and then send the syslog messages of multiple other containers to
that one.

The Dockerfile and basic instructions are available on a tiny GitHub repo:
https://github.com/jpetazzo/syslogdocker.

The concept is very simple.

First, we build a container with the following characteristics:

- has rsyslogd daemon installed, and defined as the default command;
- `/dev` is defined to be a volume;
- `/var/log` is defined to be a volume.

Here is a [Dockerfile] for such a container.

Then, we start that container; but we use an explicit host bind-mount, e.g.:

```
docker run --name syslog -d -v /tmp/syslogdev:/dev syslog
```

Why the explicit host bind-mount? Because that container will create
`/dev/log` when rsyslog starts, and we want to "pick up" that socket
and bind-mount it in our future containers, without having to bind-mount
the whole `/dev`. If we just use `--volumes-from`, we will pick up
the whole `/dev`. It won't have a big impact for now, but if later we
do fancy stuff (like adding custom devices) it could mess things up,
so let's be fine-grained.

Later versions of Docker might allow fine-grained `--volumes-from`,
which will be even better.

Then we can start any container, bind-mounting the `/dev/log` into it:

```
docker run -v /tmp/syslogdev/log:/dev/log myimage somecommand
```

For an educational example, you can do this:

```
docker run -v /tmp/syslogdev/log:/dev/log ubuntu logger hello
```

That's it! That container will send log messages to `/dev/log`,
which will actually be the socket created by rsyslogd.

You can see the logs by running another container with
`--volumes-from syslog` and checking the files in `/var/log`.

For bonus points, you can try to see what happens when you use
`journald` or something that tries to be container-aware :-)

[Dockerfile]: https://github.com/jpetazzo/syslogdocker/blob/master/Dockerfile
