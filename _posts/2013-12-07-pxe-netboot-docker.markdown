---
layout: post
title: Network booting machines with a PXE server running in a Docker container
tags: docker
---

When you want to install a new machine, or boot in rescue mode, the usual
method is to boot from a CD or USB stick. But virtually all modern computers
with an Ethernet interface can also boot from the network. Here is how to
setup a boot server super easily, by running it in a Docker container.


## Netboot 101

On Intel machines (32 or 64 bits), the network boot mechanism is called [PXE].
It uses multiple protocols:

- [DHCP] lets the booting machine discover the IP address it should use, and
  retrieve some basic parameters, like DNS, gateway, address of server to
  boot from;
- [TFTP] is used to download the code to execute -- typically a loader which,
  in turn, can fetch a Linux kernel and initrd.

PXE can be used in many scenarios; but we can simplify and consider two cases.

1. You can't (or don't want to) use a CD/USB media to install/reinstall the
   machine. If you are managing thousands of machines, you don't want to
   haul around a stack of bootable CDs or USB sticks; and you don't want
   to have to find one to reinstall a single machine, neither. My university
   was (and probably still is) using PXE to painlessly deploy Linux and
   Windows on thousands of machines. It took maybe 10 minutes for a single
   person to install, reinstall, or upgrade a lab of 25 machines.
2. You want to run totally diskless. In that case, after booting, Linux
   will typically switch to a NFS root filesystem. Since it is possible
   to operate from a read-only NFS root, it means that you can boot hundreds
   of machines from a single PXE+NFS server. Installing or upgrading
   packages is extremely easy (and doesn't require a reboot of the
   diskless machines!). Your workstations can be more reliable (since
   hard disks are often the number one failure cause), run faster
   (since a gigabit Ethernet network will have faster throughput and
   lower latency than a typical spinning disk), use less power, and
   be more silent (since you can spin down the hard disk, or remove it
   altogether).

Here, we will show how to build a PXE server (DHCP+TFTP) to boot a machine
to the Debian install system. It lets you install Debian entirely from the
network. You can of course tailor it to your needs (and I hope someone
will submit interesting pull requests to make that happen).


## Why run that in a Docker container?

As you will see, setting up a PXE server is not hard. It used to be
more complicated, but [dnsmasq] simplified the whole things immensely,
since it combines a DNS, DHCP, and TFTP server, and can be configured
entirely from the command-line.

So why bother using a container for that?

1. The setup is not hard, but it's still a bit of work (especially if
   you're not familiar with those protocols). PXE used to be very picky
   (some machines would require random magic DHCP options to be there,
   or they would just ignore the DHCP server). It got better with the
   years, but still, it's great to have something that is known to
   work, rather than re-installing the environment each time, and
   wondering if it doesn't work because you're missing some magic option
   that you forgot to write down. (Happened to me countless times,
   until I froze my whole boot server in a chroot!)
2. PXE uses DHCP, and running a DHCP server can be disruptive.
   Almost all networks use DHCP for automatic IP address allocation
   and configuration now; so if you run a DHCP server on your machine,
   you will probably disrupt the local network (and get in trouble with
   the local network administrator, unless you're the local network
   adminstrator; then you will be the one troubleshooting weird issues
   with machines suddenly misbehaving because they were "hooked" by
   your new DHCP server). It would be a good idea to have an easy way
   to start and stop the boot server. A VM would be great, but VMs
   are so 2000; this is the 2010s, so let's containerize all the things!
3. Because we can! :-)


## Pre-requirements

Of course, you need to have [Docker] on your machine. [Install] it already!

Then, you will need [pipework]. Just download it from the repository;
it's a simple shell script.


## Running the boot server

Two steps:

```
PXECID=$(docker run -d jpetazzo/pxe)
pipework br0 $PXECID 192.168.242.1/24
```

Now, the PXE server is booting anything connected to the `br0` bridge;
but usually, nothing is connected to that bridge. So, assuming that `eth0`
is your Ethernet interface, just do `brctl addif br0 eth0` -- and that's it!
Now you can boot PXE machines on the network connected to `eth0`!

Alternatively, you can put VMs on `br0` and achieve the same result.

When you want to stop the boot server, just do `docker kill $PXECID`.


## How did you build the container?

With a Dockerfile, of course. Let's look at this [Dockerfile].

First, we'll use Debian (because I love Debian).

```
FROM stackbrew/debian:jessie
```

Then, we declare some environment variables. If you want to netboot 32 bits
machines, you can change `ARCH`; if you want to install the `jessie` distribution
instead, update `DIST`. And of course you can update the mirror if you want.

```
ENV ARCH amd64
ENV DIST wheezy
ENV MIRROR http://ftp.nl.debian.org
```

Now we install the required packages. Dnsmasq is the DNS+DHCP+TFTP server.
We will need wget a bit later; and iptables will be used to give network access
to the netbooted machines.

```
RUN apt-get -q update
RUN apt-get -qy install dnsmasq wget iptables
```

We install pipework. Pipework is used in the container for one trivial thing:
waiting until `eth1` becomes available. `eth1` will appear "automagically"
when we run pipework in the host, after starting the container.

```
RUN wget --no-check-certificate https://raw.github.com/jpetazzo/pipework/master/pipework
RUN chmod +x pipework
```

Download the Linux kernel, ramdisk, and PXE boot loader from the Debian mirror.
The `WORKDIR` instruction means that all further lines will be executed in `/tftp`.

```
RUN mkdir /tftp
WORKDIR /tftp
RUN wget $MIRROR/debian/dists/$DIST/main/installer-$ARCH/current/images/netboot/debian-installer/$ARCH/linux
RUN wget $MIRROR/debian/dists/$DIST/main/installer-$ARCH/current/images/netboot/debian-installer/$ARCH/initrd.gz
RUN wget $MIRROR/debian/dists/$DIST/main/installer-$ARCH/current/images/netboot/debian-installer/$ARCH/pxelinux.0
```

Then we generate a minimal boot configuration. This works like this:

- the DHCP server will tell to the netbooted machines "hey, you should first
  execute `pxelinux.0`!"
- `pxelinux.0` is a boot loader which, in turn, will try to load a configuration
  file from `pxelinux.cfg/XXX`; it will try multiple different files in that
  directory, and will eventually try `pxelinux.cfg/default`
- this file tells to the boot loader "get the files called `linux` and `initrd.gz`
  and use them respectively as a kernel and initial ramdisk, then boot!"

```
RUN mkdir pxelinux.cfg
RUN printf "DEFAULT linux\nKERNEL linux\nAPPEND initrd=initrd.gz\n" >pxelinux.cfg/default
```

Last but not least, we define the command that should run within the container.
This one is big! We could have used a script; but since it's not *that* big,
we decided to use line continuations instead.

This command will enable network connection sharing, it will wait for the
pipework-provided network interface to come up, then it will start dnsmasq.
Dnsmasq really does all the work!

```
CMD \
    echo Setting up iptables... &&\
    iptables -t nat -A POSTROUTING -j MASQUERADE &&\
    echo Waiting for pipework to give us the eth1 interface... &&\
    /pipework --wait &&\
    echo Starting DHCP+TFTP server...&&\
    dnsmasq --interface=eth1 \
                --dhcp-range=192.168.242.2,192.168.242.99,255.255.255.0,1h \
            --dhcp-boot=pxelinux.0,pxeserver,192.168.242.1 \
            --pxe-service=x86PC,"Install Linux",pxelinux \
            --enable-tftp --tftp-root=/tftp/ --no-daemon
```


## How do I boot something else?

I hope that this container can be used as a base for more complex stuff.
If you extend it to add menus and other things, don't hesitate to submit
pull requests. It would be awesome to have a bigger, more universal, PXE
boot server!


## What's the deal with the hard-coded 192.168.242...?

I had two options when writing this: using pipework, or *not* using
pipework. First, let's see what it means to *not* use pipework.

If we don't use pipework, we need to expose the UDP ports used by
DHCP and TFTP. Then, since the goal is to boot machines sitting on
the "real" network (i.e. not the Docker internal network), we need
to probe that network to figure out the address of the default gateway,
of the DNS server, and a range of available addresses to use for DHCP.
Once we have that information, we can use it to start dnsmasq.

I think that this would have been much more complicated to get right.
In some scenarios it would have been completely impossible. So I
decided to use pipework instead, and use an arbitrary network.


## Acknowledgements...

Thanks to [Tianon], who suggested that this might be possible.
Your feedback (and your contributions to Docker in general) are awesome!


[DHCP]: http://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol
[dnsmasq]: http://www.thekelleys.org.uk/dnsmasq/doc.html
[Docker]: http://www.docker.io/
[Dockerfile]: https://github.com/jpetazzo/pxe/blob/master/Dockerfile
[install]: http://www.docker.io/gettingstarted/#h_installation
[pipework]: https://github.com/jpetazzo/pipework
[PXE]: http://en.wikipedia.org/wiki/Preboot_Execution_Environment
[TFTP]: http://en.wikipedia.org/wiki/Trivial_File_Transfer_Protocol
[Tianon]: https://github.com/tianon