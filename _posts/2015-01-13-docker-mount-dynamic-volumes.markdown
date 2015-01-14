---
layout: post
title: Attach a volume to a container while it is running
---

It has been asked on #docker-dev recently if it was possible
to attach a volume to a container *after* it was started.
At first, I thought it would be difficult, because of how
the `mnt` namespace works. Then I thought better :-)


## TL,DR

To attach a volume into a running container, we are going to:

- use [nsenter] to mount the whole filesystem containing this
  volume on a temporary mountpoint;
- create a bind mount from the specific directory that we
  want to use as the volume, to the right location of this volume;
- umount the temporary mountpoint.

It's that simple, really.

## Preliminary warning

In the examples below, I deliberately included the `$` sign
to indicate the shell prompt and help to make the difference
between what you're supposed to type, and what the machine
is supposed to answer. There are some multi-line commands,
with `>` continuation characters. I am aware that it makes
the examples really painful to copy-paste. If you want to
copy-paste code, look at the sample script at the end of this
post!


## Step by step

In the following example, I assume that I started a simple
container named `charlie`, with the following command:

    $ docker run --name charlie -ti ubuntu bash

I also assume that I want to mount the host directory
`/home/jpetazzo/Work/DOCKER/docker` to `/src` in my container.

Let's do this!


### nsenter

First, you will need [nsenter], with the `docker-enter`
helper script. Why? Because we are going to mount filesystems
from within our container, and for security reasons, our
container is not allowed to do that. Using `nsenter`, we
will be able to run an arbitrary command within the context
(technically: the namespaces) of our container, but without
the associated security restrictions. Needless to say, this
can be done only with root access on the Docker host.

The simplest way to install [nsenter] and its associated
`docker-enter` script is to run:

    $ docker run --rm -v /usr/local/bin:/target jpetazzo/nsenter

For more details, check the [nsenter] project page.


### Find our filesystem

We want to mount the filesystem containing our host directory
(`/home/jpetazzo/Work/DOCKER/docker`) in the container.

We have to find on which filesystem this directory is located.

First, we will canonicalize (or dereference) the file, just
in case it is a symbolic link - or its path contains any
symbolic link:

    $ readlink --canonicalize /home/jpetazzo/Work/DOCKER/docker
    /home/jpetazzo/go/src/github.com/docker/docker

A-ha, it is indeed a symlink! Let's put that in an environment
variable to make our life easier:

    $ HOSTPATH=/home/jpetazzo/Work/DOCKER/docker
    $ REALPATH=$(readlink --canonicalize $HOSTPATH)

Then, we need to find which filesystem contains that path.
We will use an unexpected tool for that, `df`:

    $ df $REALPATH
    Filesystem     1K-blocks      Used Available Use% Mounted on
    /sda2          245115308 156692700  86157700  65% /home/jpetazzo

Let's use the `-P` flag (to force POSIX format, just in
case you have an exotic `df`, or someone runs that on Solaris
or BSD when those systems will get Docker too) and put the
result into a variable as well:

    $ FILESYS=$(df -P $REALPATH | tail -n 1 | awk '{print $6}')


### Find the device (and sub-root) of our filesystem

Now, in a world without bind mounts or BTRFS subvolumes,
we would just have to look into `/proc/mounts` to find out
the device corresponding to the `/home/jpetazzo` filesystem,
and we would be golden. But on my system, `/home/jpetazzo`
is a subvolume on a BTRFS pool. To get subvolume information
(or bind mount information), we will check `/proc/self/mountinfo`.

If you had never heard about mountinfo, check [proc.txt]
in the kernel docs, and be enlightened :-)

So, first, let's retrieve the device of our filesystem:

    $ while read DEV MOUNT JUNK
    > do [ $MOUNT = $FILESYS ] && break
    > done </proc/mounts
    $ echo $DEV
    /dev/sda2

Next, retrieve the sub-root (i.e. the path of the mounted
filesystem, within the global filesystem living in this
device):

    $ while read A B C SUBROOT MOUNT JUNK
    > do [ $MOUNT = $FILESYS ] && break
    > done < /proc/self/mountinfo 
    $ echo $SUBROOT
    /jpetazzo

Perfect. Now we know that we will need to mount `/dev/sda2`,
and inside that filesystem, go to `/jpetazzo`, and from there,
to the remaining path to our file (in our example,
`/go/src/github.com/docker/docker`).

Let's compute this remaining path, by the way:

    $ SUBPATH=$(echo $REALPATH | sed s,^$FILESYS,,)

Note: this works as long as there are no `,` in the path.
If you have an idea to make that work regardless of the
funky characters that might be in the path, let me know!
(I shall invoke the Shell Triad to the rescue: [jessie],
[soulshake], [tianon]?)

The last thing that we need to do before diving into the
container, is to resolve the major and minor device numbers
for this block device. `stat` will do it for us:

    $ stat --format "%t %T" $DEV
    8 2

Note that those numbers are in hexadecimal, and later, we will
need them in decimal. Here is a hackish way to convert them
easily:

    $ DEVDEC=$(printf "%d %d" $(stat --format "0x%t 0x%T" $DEV))


### Putting it all together

There is one last subtle hack. For reasons that are beyond my
understanding, some filesystems (including BTRFS) will update
the device field in `/proc/mounts` when you mount them multiple
times. In other words, if we create a temporary block device
named `/tmpblkdev` in our container, and use that to mount our
filesystem, then now our filesystem (in the host!) will appear as
`/tmpblkdev` instead of e.g. `/dev/sda2`. This sounds like a
little detail, but in fact, it will screw up all future attempts
to resolve the filesystem block device.

Long story short: we have to make sure that the block device node
in the container is located at the same path than its counterpart
on the host.

Let's do this:

    $ docker-enter charlie -- sh -c \
    > "[ -b $DEV ] || mknod --mode 0600 $DEV b $DEVDEC"

Create a temporary mount point, and mount the filesystem:

    $ docker-enter charlie -- mkdir /tmpmnt
    $ docker-enter charlie -- mount $DEV /tmpmnt

Make sure that the volume mount point exists, and bind mount
the volume on it:

    $ docker-enter charlie -- mkdir -p /src
    $ docker-enter charlie -- mount -o bind /tmpmnt/$SUBROOT/$SUBPATH /src

Cleanup after ourselves:

    $ docker-enter charlie -- umount /tmpmnt
    $ docker-enter charlie -- rmdir /tmpmnt

(We don't clean up the device node. We could be extra fancy
and detect whether the device existed in the first place, but
this is already pretty complex as it is right now!)

*Voilà!*


### Automating the hell out of it

This little snippet is almost copy-paste ready.

```sh
#!/bin/sh
set -e
CONTAINER=charlie
HOSTPATH=/home/jpetazzo/Work/DOCKER/docker
CONTPATH=/src

REALPATH=$(readlink --canonicalize $HOSTPATH)
FILESYS=$(df -P $REALPATH | tail -n 1 | awk '{print $6}')

while read DEV MOUNT JUNK
do [ $MOUNT = $FILESYS ] && break
done </proc/mounts
[ $MOUNT = $FILESYS ] # Sanity check!

while read A B C SUBROOT MOUNT JUNK
do [ $MOUNT = $FILESYS ] && break
done < /proc/self/mountinfo 
[ $MOUNT = $FILESYS ] # Moar sanity check!

SUBPATH=$(echo $REALPATH | sed s,^$FILESYS,,)
DEVDEC=$(printf "%d %d" $(stat --format "0x%t 0x%T" $DEV))

docker-enter $CONTAINER -- sh -c \
	     "[ -b $DEV ] || mknod --mode 0600 $DEV b $DEVDEC"
docker-enter $CONTAINER -- mkdir /tmpmnt
docker-enter $CONTAINER -- mount $DEV /tmpmnt
docker-enter $CONTAINER -- mkdir -p $CONTPATH
docker-enter $CONTAINER -- mount -o bind /tmpmnt/$SUBROOT/$SUBPATH $CONTPATH
docker-enter $CONTAINER -- umount /tmpmnt
docker-enter $CONTAINER -- rmdir /tmpmnt
```

## Status and limitations

This will not work on filesystems which are not based on block devices.

It will only work if `/proc/mounts` correctly lists the block device
node (which, as we saw above, is not necessarily true).

Also, I only tested this on my local environment; I didn't even try
on a cloud instance or anything like that, but I would love to know
if it works there or not!


[nsenter]: https://github.com/jpetazzo/nsenter
[proc.txt]: https://www.kernel.org/doc/Documentation/filesystems/proc.txt
[jessie]: https://twitter.com/frazelledazzell
[soulshake]: https://twitter.com/s0ulshake
[tianon]: https://twitter.com/tianon