---
layout: post
title: Resizing Docker containers with the Device Mapper plugin
tags: docker
---

If you're using Docker on CentOS, RHEL, Fedora, or any other distro
that doesn't ship by default with AUFS support, you are probably
using the Device Mapper storage plugin. By default, this plugin
will store all your containers in a 100 GB sparse file, and each
container will be limited to 10 GB. This article will explain how
you can change that limit, and move container storage to a dedicated
partition or LVM volume.


## Warning

At some point, Docker storage driver internals have changed
significantly, and the technique described here doesn't work
anymore. If you want to change the filesystem size for
Docker containers using the Device Mapper storage driver,
you should use the `--storage-opt` flag of the Docker Engine.

You can find abundant documentation for the `--storage-opt`
flag in the [Docker Engine reference documentation](
https://docs.docker.com/engine/reference/commandline/daemon/#storage-driver-options).

The rest of this article has been left for historical
purposes, but take it with a grain of salt. The downside
of fast-changing, rapidly-evolving software projects is
that nothing is ever cast in stone! :-)


## How it works

To really understand what we're going to do, let's look how the
Device Mapper plugin works.

It is based on the Device Mapper "thin target". It's actually a
snapshot target, but it is called "thin" because it allows
*thin provisioning*. Thin provisioning means that you have a
(hopefully big) pool of available storage blocks, and you create
block devices (virtual disks, if you will) of arbitrary size
from that pool; but the blocks will be marked as used (or "taken"
from the pool) only when you actually write to it.

This means that you can oversubscribe the pool; e.g. create thousands
of 10 GB volumes with a 100 GB pool, or even a 100 TB volume on a 1 GB
pool. As long as you don't actually *write* more blocks than you
actually have in the pool, everything will be fine.

Additionally, the thin target is able to perform snapshots. It means
that at any time, you can create a shallow copy of an existing volume.
From a user point of view, it's exactly as if you now had two identical
volumes, that can be changed independently. As if you had made a full
copy, except that it was instantaneous (even for large volumes), and
they don't use twice the storage. Additional storage is used only when
changes are made in one of the volumes. Then the thin target allocates
new blocks from the storage pool.

Under the hood, the "thin target" actually uses two storage devices:
a (large) one for the pool itself, and a smaller one to hold metadata.
This metadata contains information about volumes, snapshots, and the
mapping between the blocks of each volume or snapshot, and the blocks
in the storage pool.

When Docker uses the Device Mapper storage plugin, it will create
two files (if they don't already exist) in
`/var/lib/docker/devicemapper/devicemapper/data` and
`/var/lib/docker/devicemapper/devicemapper/metadata` to hold
respectively the storage pool and associated metadata. This is
very convenient, because no specific setup is required on your side
(you don't need an extra partition to store Docker containers, or
to setup LVM or anything like that). However, it has two drawbacks:

- the storage pool will have a default size of 100 GB;
- it will be backed by a sparse file, which is great from a disk
  usage point of view (because just like volumes in the thin pool,
  it starts small, and actually uses disk blocks only when it gets
  written to) but less great from a performance point of view,
  because the VFS layer adds some overhead, especially for the
  "first write" scenario.

Before checking how to resize a container, we will see how to
make more room in that pool.


## We need a bigger pool

**Warning:** the following will delete all your containers and all
your images. Make sure that you backup any precious data!

Remember what we said above: Docker will create the `data` and `metadata`
files *if they don't exist*. So the solution is pretty simple: just
create the files for Docker, before starting it!

1. Stop the Docker daemon, because we are going to reset the storage
   plugin, and if we remove files while it is running, Bad Things Will
   Happen©.
2. Wipe out `/var/lib/docker`. **Warning:** as mentioned above, this
   will delete all your containers all all your images.
3. Create the storage directory:
   `mkdir -p /var/lib/docker/devicemapper/devicemapper`.
4. Create your pool:
   `dd if=/dev/zero of=/var/lib/docker/devicemapper/devicemapper/data
   bs=1G count=0 seek=250` will create a sparse file of 250G. If
   you specify `bs=1G count=250` (without the `seek` option) then
   it will create a normal file (instead of a sparse file).
5. Restart the Docker daemon. Note: by default, if you have AUFS
   support, Docker will use it; so if you want to enforce the use
   of the Device Mapper plugin, you should add `-s devicemapper`
   to the command-line flags of the daemon.
6. Check with `docker info` that `Data Space Total` reflects the
   correct amount.


## We need a faster pool

**Warning:** the following will also delete all your containers and
images. Make sure you pull your important images to a registry, and
save any important data you might have in your containers.

An easy way to get a faster pool is to use a real device instead of a
file-backed loop device. The procedure is almost the same. Assuming
that you have a completely empty hard disk, `/dev/sdb`, and that you
want to use it entirely for container storage, you can do this:

1. Stop the Docker daemon.
2. Wipe out `/var/lib/docker`. (That should sound familiar, right?)
3. Create the storage directory:
   `mkdir -p /var/lib/docker/devicemapper/devicemapper`.
4. Create a `data` symbolic link in that directory, pointing to the device:
   `ln -s /dev/sdb /var/lib/docker/devicemapper/devicemapper/data`.
5. Restart Docker.
6. Check with `docker info` that the `Data Space Total` value is correct.


## Using RAID and LVM

If you want to consolidate multiple similar disks, you can use software
RAID10. You will end up with a `/dev/mdX` device, and will link to that.
Another very good option is to turn your disks (or RAID arrays) into
[LVM] Physical Volumes, and then create two Logical Volumes, one
for data, another for metadata. I don't have specific advices regarding
the optimal size of the metadata pool; it looks like 1% of the data pool
would be a good idea.

Just like above, stop Docker, wipe out its data directory, then create
symbolic links to the devices in `/dev/mapper`, and restart Docker.

If you need to learn more about LVM, check the [LVM howto].


## Growing containers

By default, if you use the Device Mapper storage  plugin, all images and
containers are created from an initial filesystem of 10 GB. Let's see how
to get a bigger filesystem for a given container.

First, let's create our container from the Ubuntu image. We don't need
to run anything in this container; we just need it (or rather, its
associated filesystem) to exist. For demonstration purposes, we will run
`df` in this container, to see the size of its root filesystem.

```
$ docker run -d ubuntu df -h /
4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603
```

We now have to run some commands *as root*, because we will be affecting
the volumes managed by the Device Mapper. In the instructions below,
all the commands denoted with `#` have to run as root. You can run the
other commands (starting with the `$` prompt) as your regular user, as
long as it can access the Docker socket, of course.

Let's look into /dev/mapper; there should be a symbolic link corresponding
to this container's filesystem. It will be prefixed with `docker-X:Y-Z-`:

```
# ls -l /dev/mapper/docker-*-4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603
lrwxrwxrwx 1 root root 7 Jan 31 21:04 /dev/mapper/docker-0:37-1471009-4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603 -> ../dm-8
```

Note that full name; we will need it. First, let's have a look at the
current *table* for this volume:

```
# dmsetup table docker-0:37-1471009-4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603
0 20971520 thin 254:0 7
```

The second number is the size of the device, in 512-bytes sectors. The value
above corresponds to 10 GB.

Let's compute how many sectors we need for a 42 GB volume:

```
$ echo $((42*1024*1024*1024/512))
88080384
```

An amazing feature of the thin snapshot target is that it doesn't limit the size
of the volumes. When you create it, a thin provisioned volume uses zero blocks,
and as you start writing to those blocks, they are allocated from the common block
pool. But you can start writing block 0, or block 1 billion: it doesn't matter
to the thin snapshot target. The only thing determining the size of the filesystem
is the Device Mapper table.

Confused? Don't worry. The TL,DR is: we just need to load a new table, which
will be exactly the same as before, but with more sectors. Nothing else.

The old table was `0 20971520 thin 254:0 7`. We will change the second number, and
*be extremely careful about leaving everything else exactly as it is*. Your volume
will probably not be `7`, so use the right values!

So let's do this:

```
# echo 0 88080384 thin 254:0 7 | dmsetup load docker-0:37-1471009-4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603
```

Now, if we check the table again, it will *still be the same* because the new table
has to ba activated first, with the following command:

```
# dmsetup resume docker-0:37-1471009-4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603
```

After that command, check the table one more time, and it will have the new number
of sectors.

We have resized the block device, but we still need to resize the filesystem.
This is done with `resize2fs`:

```
# resize2fs /dev/mapper/docker-0:37-1471009-4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603
resize2fs 1.42.5 (29-Jul-2012)
Filesystem at /dev/mapper/docker-0:37-1471009-4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603 is mounted on /var/lib/docker/devicemapper/mnt/4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603; on-line resizing required
old_desc_blocks = 1, new_desc_blocks = 3
The filesystem on /dev/mapper/docker-0:37-1471009-4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603 is now 11010048 blocks long.
```

As an optional step, we will restart the container, to check that we indeed have
the right amount of free space:

```
$ docker start 4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603
$ docker logs 4ab0bdde0a0dd663d35993e401055ee0a66c63892ba960680b3386938bda3603
df: Warning: cannot read table of mounted file systems: No such file or directory
Filesystem      Size  Used Avail Use% Mounted on
-               9.8G  164M  9.1G   2% /
df: Warning: cannot read table of mounted file systems: No such file or directory
Filesystem      Size  Used Avail Use% Mounted on
-                42G  172M   40G   1% /
```

Want to automate the whole process? Sure:

```
CID=$(docker run -d ubuntu df -h /)
DEV=$(basename $(echo /dev/mapper/docker-*-$CID))
dmsetup table $DEV | sed "s/0 [0-9]* thin/0 $((42*1024*1024*1024/512)) thin/" | dmsetup load $DEV
dmsetup resume $DEV
resize2fs /dev/mapper/$DEV
docker start $CID
docker logs $CID
```

## Growing images

Unfortunately, the current version of Docker won't let you
grow an image as easily. You can grow the block device associated
with an image, then create a new container from it, but the new
container won't have the right size.

Likewise, if you commit a large container, the resulting image
won't be bigger (this is due to the way that Docker will prepare
the filesystem for this image).

It means that currently, if a container is really more than 10 GB,
you won't be able to commit it correctly without additional tricks.


## Conclusions

Docker will certainly expose nicer ways to grow containers, because
the code changes required are very small. Managing the thin pool
and its associated metadata is a bit more complex (since there are
many different scenarios involved, and a potential data migration,
that we did not cover here, since we wiped out everything when
building the new pool), but the solutions that we described will
take you pretty far already.

As usual, if you have further questions or comments, don't hesitate
to ping me on IRC (jpetazzo on Freenode) or Twitter ([@jpetazzo])!


[@jpetazzo]: https://twitter.com/jpetazzo
[LVM]: http://en.wikipedia.org/wiki/Logical_Volume_Manager_(Linux)
[LVM howto]: http://tldp.org/HOWTO/LVM-HOWTO/
