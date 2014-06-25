---
layout: post
title: "If you run SSHD in your Docker containers, you're doing it wrong!"
---

When they start using Docker, people often ask: "How do I get inside
my containers?" and other people will tell them "Run an SSH server
in your containers!" but that's a very bad practice. We will see
why it's wrong, and what you should do instead.


## Your containers should not run an SSH server

…Unless your container *is* an SSH server, of course.

It's tempting to run the SSH server, because it gives an easy way to
"get inside" of the container. Virtually everybody in our craft used
SSH at least once in their life. Most of us use it on a daily basis,
and are familiar with public and private keys, password-less logins,
key agents, and even sometimes port forwarding and other niceties.

With that in mind, it's not surprising that people would advise you
to run SSH within your container. But you should think twice.

Let's say that you are building a Docker image for a Redis server
or a Java webservice. I would like to ask you a few questions.

- What do you need SSH for?

  Most likely, you want to do backups, check logs, maybe restart
  the process, tweak the configuration, possibly debug the server
  with gdb, strace, or similar tools. We will see how to do those
  things without SSH.

- How will you manage keys and passwords?

  Most likely, you will either bake those into your image, or
  put them in a volume. Think about what you should do when you
  want to update keys or passwords. If you bake them into the
  image, you will need to rebuild your images, redeploy them, and
  restart your containers. Not the end of the world, but not very
  elegant neither. A much better solution is to put the credentials
  in a volume, and manage that volume. It works, but has significant
  drawbacks. You should make sure that the container does not have
  write access to the volume; otherwise, it could corrupt the
  credentials (preventing you from logging into the container!),
  which could be even worse if those credentials are shared across
  multiple containers. If only SSH could be elsewhere, that would
  be one less thing to worry about, right?

- How will you manage security upgrades?

  The SSH server is pretty safe, but still, when a security issue
  arises, you will have to upgrade *all* the containers using SSH.
  That means rebuilding and restarting *all* of them. That also
  means that even if you need a pretty innocuous memcached service,
  you have to stay up-to-date with security advisories, because
  the attack surface of your container is suddenly much bigger.
  Again, if SSH could be elsewhere, that would be a nice *separation
  of concerns*, wouldn't it?

- Do you need to "just add the SSH server" to make it work?

  No. You also need to add a process manager; for instance [Monit]
  or [Supervisor]. This is because Docker will watch one single
  process. If you need multiple processes, you need to add one
  at the top-level to take care of the others. In other words,
  you're turning a lean and simple container into something much
  more complicated. If your application stops (if it exits cleanly
  or if it crashes), instead of getting that information through
  Docker, you will have to get it from your process manager.

- You are in charge of putting the app inside a container, but
  are you also in charge of access policies and security compliance?

  In smaller organizations, that doesn't matter too much. But in
  larger groups, if you are the person putting the app in a container,
  there is probably a different person responsible for defining
  remote access policies. Your company might have strict policies
  defining who can get access, how, and what kind of audit trail
  is required. In that case, you definitely *don't* want to put
  a SSH server in your container.


## But how do I ...


### Backup my data?

Your data should be in a [volume]. Then, you can run another
container, and with the `--volumes-from` option, share that
volume with the first one. The new container will be dedicated
to the backup job, and will have access to the required data.

Added benefit: if you need to install new tools to make your
backups or to ship them to long term storage (like `s3cmd`
or the like), you can do that in the special-purpose backup
container instead of the main service container. It's cleaner.


### Check logs?

Use a [volume]! Yes, again. If you write all your logs under
a specific directory, and that directory is a volume, then
you can start another "log inspection" container (with
`--volumes-from`, remember?) and do everything you need here.

Again, if you need special tools (or just a fancy `ack-grep`),
you can install them in the other container, keeping your
main container in pristine condition.


### Restart my service?

Virtually all services can be restarted with signals. When
you issue `/etc/init.d/foo restart` or `service foo restart`,
it will almost always result in sending a specific signal to
a process. You can send that signal with `docker kill -s <signal>`.

Some services won't listen to signals, but will accept commands
on a special socket. If it is a TCP socket, just connect over
the network. If it is a UNIX socket, you will use... a volume,
one more time. Setup the container and the service so that the
control socket is in a specific directory, and that directory is
a volume. Then you can start a new container with access to that
volume; it will be able to use the socket.

"But, this is complicated!" - not really. Let's say that your
service `foo` creates a socket in `/var/run/foo.sock`, and
requires you to run `fooctl restart` to be restarted cleanly.
Just start the service with `-v /var/run` (or add `VOLUME
/var/run` in the Dockerfile). When you want to restart,
execute the exact same image, but with the `--volumes-from`
option and overriding the command. This will look like this:

    # Starting the service
    CID=$(docker run -d -v /var/run fooservice)
    # Restarting the service with a sidekick container
    docker run --volumes-from $CID fooservice fooctl restart

It's that simple!


### Edit my configuration?

If you are performing a durable change to the configuration, it
should be done in the image - because if you start a new container,
the old configuration will be there again, and your changes will
be lost. So, no SSH access for you!

*"But I need to change my configuration over the lifetime of my
service; for instance to add new virtual hosts!"*

In that case, you should use... wait for it... a volume! The
configuration should be in a volume, and that volume should be
shared with a special-purpose "config editor" container. You
can use anything you like in this container: SSH + your favorite
editor, or an web service accepting API calls, or a crontab
fetching the information from an outside source; whatever.

Again, you're separating concerns: one container runs the service,
another deals with configuration updates.

*"But I'm doing temporary changes, because I'm testing different
values!*

In that case, check the next section!


### Debug my service?

That's the only scenario where you *really* need to get a shell
into the container. Because you're going to run gdb, strace,
tweak the configuration, etc.

In that case, you need `nsenter`.


## Introducing `nsenter`

`nsenter` is a small tool allowing to `enter` into `n`ame`s`paces.
Technically, it can enter existing [namespaces], or spawn a process
into a new set of namespaces. "What are those namespaces you're
blabbering about?" They are one of the essential constituants
of containers.

The short version is: **with `nsenter`, you can get a shell into
an existing container**, even if that container doesn't run SSH
or any kind of special-purpose daemon.


### Where do I get `nsenter`?

Check [jpetazzo/nsenter] on GitHub. The short version is that if you run:

    docker run -v /usr/local/bin:/target jpetazzo/nsenter

… this will install `nsenter` in `/usr/local/bin` and you will be able
to use it immediately.

`nsenter` might also be available in your distro (in the `util-linux`
package).


### How do I use it?

First, figure out the PID of the container you want to enter:

    PID=$(docker inspect --format {{ "{{.State.Pid}}" }} <container_name_or_ID>)

Then enter the container:

    nsenter --target $PID --mount --uts --ipc --net --pid

You will get a shell inside the container. That's it.

If you want to run a specific script or program in an automated manner,
add it as argument to `nsenter`. It works a bit like `chroot`, except
that it works with containers instead of plain directories.


### What about remote access?

If you need to enter a container from a remote host, you have (at least)
two ways to do it:

- SSH into the Docker host, and use `nsenter`;
- SSH into the Docker host, where a special key with force a specific
  command (namely, `nsenter`).

The first solution is pretty easy; but it requires root access to the
Docker host (which is not great from a security point of view).

The second solution uses the `command=` pattern in SSH's `authorized_keys`
file. You are probably familiar with "classic" `authorized_keys` files,
which look like this:

    ssh-rsa AAAAB3N…QOID== jpetazzo@tarrasque

(Of course, a real key is much longer, and typically spans multiple lines.)

You can also force a specific command. If you want to be able to check
the available memory on your system from a remote host, using SSH keys,
but you don't want to give full shell access, you can put this in the
`authorized_keys` file:

    command="free" ssh-rsa AAAAB3N…QOID== jpetazzo@tarrasque

Now, when that specific key connects, instead of getting a shell, it will
execute the `free` command. It won't be able to do anything else.

(Technically, you probably want to add `no-port-forwarding`; check the
manpage `authorized_keys(5)` for more information.)

The crux of this mechanism is to split responsibilities. Alice puts
services within containers; she doesn't deal with remote access, logging,
and so on. Betty will add the SSH layer, to be used only in exceptional
circumstances (to debug weird issues). Charlotte will take care of 
logging. And so on.


## Wrapping up

Is it really Wrong (uppercase double you) to run the SSH server in
a container? Let's be honest, it's not that bad. It's even super
convenient when you don't have access to the Docker host, but still
need to get a shell within the container.

But we saw here that there are many ways to *not* run an SSH server
in a container, and *still* get all the features we want, with a
much cleaner architecture.

Docker allows you to use whatever workflow is best for you. But
before jumping in the "my container is really a small VPS" bandwagon,
be aware that there are other solutions, so you can make an
informed decision!


[Monit]: http://mmonit.com/monit/
[Supervisor]: http://supervisord.org/
[volume]: https://docs.docker.com/userguide/dockervolumes/
[namespaces]: http://blog.dotcloud.com/under-the-hood-linux-kernels-on-dotcloud-part
[jpetazzo/nsenter]: https://github.com/jpetazzo/nsenter
