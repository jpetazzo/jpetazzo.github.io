---
title: "The Quest for Minimal Docker Images, part 3"
layout: post
---

In the beginning of this series ([first part], [second part]),
we covered the most common
methods to optimize Docker image size. We saw how multi-stage builds,
combined with Alpine-based images, and sometimes static builds,
would generally give us the most dramatic savings. In this last part,
we will see how to go even farther. We will talk about standardizing
base images, stripping binaries, assets optimization, and other
build systems or add-ons like DockerSlim or Bazel, as well as
the NixOS distribution.

We'll also talk about small details that we left out earlier,
but are important nonetheless, like timezone files and
certificates.

{% include minimal_docker_header.markdown %}

## Common bases

If our nodes run many containers in parallel (or even just a few),
there's one thing that can also yield significant savings.

Docker images are made of *layers*. Each layer can add, remove,
or change files; just like a commit in a code repository, or a
class inheriting from another one. When we execute a `docker build`,
each line of the Dockerfile will generate one layer. When we transfer
an image, we only transfer the layers that don't already exist on
the destination.

Layers save network bandwidth, but also storage space: if multiple
images share layers, Docker needs to store these layers only once.
And depending on the storage driver that you use, layers can also
save disk I/O and memory, because when multiple containers need
to read the same files from a layer, the system will read and cache
these files only once. (This is the case with the overlay2 and aufs
drivers.)

This means that if we're trying to optimize network and disk access,
as well as memory usage, in nodes running many containers, we can
save a lot by making sure that these containers run images that have
as many common layers as possible.

This can directly go against some of the guidelines that we gave before!
For instance, if we're building super optimized images using static
binaries, these binaries might be 10x bigger than their dynamic equivalents.
Let's look at a few hypothetical scenarios when running 10 containers,
each using a different image with one of these binaries.

Scenario 1: static binaries in a `scratch` image
- weight of each image: 10 MB
- weight of the 10 images: 100 MB

Scenario 2: dynamic binaries with `ubuntu` image (64 MB)
- individual weight of each image: 65 MB
- breakdown of each image: 64 MB for `ubuntu` + 1 MB for the specific binary
- total disk usage: 74 MB (10x1 MB for individual layers + 64 MB for shared layers)

Scenario 3: dynamic binaries with `alpine` image (5.5 MB)
- individual weight of each image: 6.5 MB
- breakdown of each image: 5.5 MB for `alpine` + 1 MB for the specific binary
- total disk usage: 15.5 MB

These static binaries looked like a good idea at first, but in these
circumstances, they are highly counterproductive. The images will require
more disk space, take longer to transfer, and use more RAM!

However, for these scenarios to work, we need to make sure that all images
actually use the exact same base. If we have some images using `centos`
and others using `debian`, we're ruining it. Even if we're using e.g.
`ubuntu:16.04` and `ubuntu:18.04`. Even if we're using two different
versions of `ubuntu:18.04`! This means that when the base image
is updated, we should rebuild all our images, to make sure that it's
consistent across all our containers.

This also means that we need to have good governance and good
communication between teams. You might be thinking, "that's not
a technical issue!", and you'd be right! It's not a technical issue.
Which means that for some folks, it will be much more difficult to
address, because there is no amount of work that you can do
*by yourself* that will solve it: you will have to involve other humans!
Perhaps you *absolutely* want to use Debian, but another team
*absolutely* wants to use Fedora. If you want to use common bases,
you will have to convince that other team.
Which means that you have to accept that
they might convince you, too. Bottom line: in some scenarios,
the most efficient solutions are the ones that require social skills,
not technical skills!

Finally, there is one specific case where static images can still be
useful: when we know that our images are going to be deployed in
heterogenous environments; or when they will be the only thing running
on a given node. In that case, there won't be any sharing happening anyway.


## Stripping and converting

There are some extra techniques that are not specific to containers,
and that can shave off a few megabytes (or sometimes just kilobytes)
from our images.


### Stripping binaries

By default, most compilers generate binaries
with symbols that can be useful for debugging or troubleshooting, but
that aren't strictly necessary for execution. The tool `strip` will
remove these symbols. This is not likely to be a game changer, but
if you are in a situation where every byte counts, it'll definitely help.


### Dealing with assets

If our container image
contains media files, can we shrink these, for instance by using
different file formats or codecs? Can we host them somewhere else,
so that the image that we ship is smaller? The latter is particularly
useful if the code changes often, but the assets don't. In that case,
we should try to avoid shipping the assets each time we ship a new release
of the code.


### Compression: a bad good idea

If we want to reduce the size of our images, why not compress our files?
Assets like HTML, javascript, CSS, should compress pretty well with
zip or gzip. There are even more efficient methods like bzip2, 7z, lzma.
At first, it looks like a simple way to reduce image size. And if we plan
on serving these assets in compressed form, why not. But if our plan
is to uncompress these assets before using them, then we will end up
wasting resources!

Layers are already compressed before being transferred, so pulling
our images won't be any faster. And if we need to uncompress the files,
the disk usage will be even higher than before, because on disk,
we will now have both the compressed and uncompressed versions of the
files! Worse: if these files are on shared layers, we won't get
any benefits from the sharing, since these files that we will uncompress
when running our containers *won't* be shared.

What about [UPX](https://upx.github.io/)?
If you're not familiar with UPX, it's an amazing tool
that reduces the size of binaries. It does so by compressing the binary,
and adding a small stub to uncompress and run it transparently.
If we want to reduce the footprint of our containers, UPX will also be
very counter-productive. First, the disk and network usage won't
be reduced a single bit, since layers are compressed anyway; so UPX
won't get us anything here.

When running a normal binary, it is mapped in memory, so that only
the bits that are needed get loaded (or “paged in”) when necessary.
When running a binary compressed with UPX, the entire binary has to be
uncompressed in memory. This results in higher memory usage and longer
start times, especially with runtimes like Go that tend to generate
bigger binaries.

(I once tried to use UPX on the [hyperkube](https://stackoverflow.com/a/33967582/580281)
binary when trying to build optimized node images to run a local
Kubernetes cluster in KVM. It didn't go well, because while it
reduced the disk usage for my VMs, their memory usage went up,
by *a lot*!)


## ... And a few exotic techniques

There are other tools that can help us achieve smaller image sizes.
This won't be an exhaustive list ...


### DockerSlim

[DockerSlim](https://github.com/docker-slim/docker-slim)
offers an almost magic technique to reduce the size
of our images. I don't know exactly how it works under the hood
(beyond the [design explanations](https://github.com/docker-slim/docker-slim#design) in the README), so I'm going to make educated guesses.
I suppose that DockerSlim runs our container, and checks which files
were accessed by the program running in our container. Then it removes
the other files. Based on that guess, I would be very careful before
using DockerSlim, because many runtimes and frameworks are loading
files dynamically, or lazily (i.e. the first time they are needed).

To test that hypothesis, I tried DockerSlim with a simple
Django application. DockerSlim reduced it from 200 MB to 30 MB,
which is great! However, while the home page of the app worked
fine, many links were broken. I suppose this is because their
templates hadn't been detected by DockerSlim, and weren't included
in the final image. Error reporting itself was also broken,
perhaps because the modules used to
display and send exceptions were skipped as well.
Any Python code that would dynamically `import` some module
would run into this.

Don't get me wrong, though: in many scenarios, DockerSlim can still
do wonders for us! As always, when there is a very powerful tool
like this, it is very helpful to understand its internals, because
it can give us a pretty good idea about how it will behave.


### Distroless

[Distroless](https://github.com/GoogleContainerTools/distroless)
images are a collection of minimal images that are built with
external tools, without using a classic Linux distribution package
manager. It results in very small images, but without basic
debugging tools, and without easy ways to install them.

As a matter of personal taste, I prefer having a package manager
and a familiar distro, because who knows what extra tool I might need
to troubleshoot a live container issue? Alpine is only 5.5 MB,
and will allow me to install virtually everything I need. I don't know
if I want to let go of that! But if you have comprehensive methods
to troubleshoot your containers without ever needing to execute
tools from their image, then by all means, you can achieve some
extra savings with Distroless.

Additionally, Alpine-based images will often be smaller than their
Distroless equivalents. So you might wonder: why should we care
about Distroless? For at least a couple of reasons.

First, from a security standpoint, Distroless images let you
have very minimal images. Less stuff in the image means less
potential vulnerabilities.

Second, Distroless images are built with Bazel, so if you want
to learn or experiment with or use Bazel, they are a great
collection of very solid examples to get started.
What's Bazel exactly?
I'm glad you asked, and I'll cover it in the next section!


### Bazel (and other alternative builders)

There are some build systems that don't even use Dockerfiles.
[Bazel](https://bazel.build/) is one of them.
The strength of Bazel is that it can
express complex dependencies between our source code and the targets
that it builds, a bit like a Makefile. This allows it to rebuild
only the things that need to be rebuilt; whether it's in our
code (when making a small local change) or our base images
(so that patching or upgrading a library doesn't trigger an entire
rebuild of all our images). It can also drive unit tests, with
the same efficiency, and run tests only for the modules that are
affected by a code change.

This becomes particularly effective on very large code bases.
At some point, our build and test system might need hours to run.
And then it needs days, and we deploy parallel build farms and
test runners, and it takes hours again, but requires lots of resources,
and can't run in a local environment anymore. It's around that
stage that something like Bazel will really shine, because it
will be able to build and test only what's needed, in
minutes instead of hours or days.

Great! So should we jump to Bazel right away? Not so fast.
Using Bazel requires learning a totally different build system,
and might be significantly more complicated that Dockerfiles,
even with all the fancy multi-stage builds and subtleties of
static and dynamic libraries that we mentioned above.
Maintaining this build system and the associated recipes
will require significantly more work. While I don't have first-hand
experience with Bazel myself, according to what I've seen
around me, it's not unreasonable to plan for at least one full-time
senior or principal engineer just to bear the burden of
setting up and maintaining Bazel.

If our organization has hundreds of developers; if build or test
times are becoming a major blocker and hinder our velocity;
then it might be a good idea to invest in Bazel. Otherwise,
if we're a fledgeling startup or small organization, it may
not be the best decision; unless we have a few engineers on
board who happen to know Bazel very well and want to set it up
for everyone else.


## Nix

I decided to add a whole section about the [Nix package manager](https://nixos.org/nix/)
because after the publication of parts 1 and 2,
some folks brought it up with a lot of enthusiasm.

Spoiler alert: yes, Nix can help you achieve better builds, but
the learning curve is steep. Maybe not as steep as with Bazel, but close.
You will need to learn Nix, its concepts, its custom
[expression language](https://wiki.nixos.org/wiki/Nix_Expression_Language),
and how to use it to package code for your favorite language and
framework (see the [nixpkgs manual](https://nixos.org/nixpkgs/manual/#chap-language-support)
for examples).

Still, I want to talk about Nix, for two
reasons: its core concepts are very powerful (and can help us
to have better ideas about software packaging in general), and
there is a particular project called [Nixery](https://nixery.dev/)
that can help us when deploying containers.


### What's Nix?

The first time I heard about Nix was about 10 years ago, when I
attended [that conference talk](http://2010.rmll.info/NixOS-The-Only-Functional-GNU-Linux-Distribution.html).
Back then, it was already full-featured and solid. It's not a
brand new hipster thing.

A little bit of terminology:
- Nix is a *package manager*, that you can install on any Linux machine, as well as on macOS;
- NixOS is a *Linux distribution* based on Nix;
- `nixpkgs` is a collection of packages for Nix;
- a "derivation" is a Nix build recipe.

Nix is a *functional* package manager. "Functional" means that every
package is defined by its *inputs* (source code, dependencies…) and its *derivation*
(build recipe), and nothing else. If we use the same inputs and the same
derivation, we get the same output. However, if we change something in
the inputs (if we edit a source file, or change a dependency) or in
the build recipe, the output changes. That makes sense, right?
If it reminds us of the Docker build cache, it's perfectly normal:
it's exactly the same idea!

On a traditional system, when a package depends on another, the
dependency is usually expressed very loosely. For instance, in Debian,
[python3.8](https://packages.debian.org/bullseye/python3.8) depends
on `python3.8-minimal (= 3.8.2-1)` but that
[python3.8-minimal](https://packages.debian.org/bullseye/python3.8-minimal)
depends on `libc6 (>= 2.29)`. On the other hand, 
[ruby2.5](https://packages.debian.org/bullseye/ruby2.5) depends on
`libc6 (>= 2.17)`. So we install a single version of `libc6` and it mostly
works.

On Nix, packages depend on *exact* versions of libraries, and
there is a very clever mechanism in place so that every program
will use its own set of libraries without conflicting with the others.
(If you wonder of this works: dynamically linked programs are using
a linker that is set up to use libraries from specific paths. Conceptually,
it's not different from specifying `#!/usr/local/bin/my-custom-python-3.8`
to run your Python script with a particular version of the Python interpreter.)

For instance, when a program uses the C library, on a classic
system, it refers to `/usr/lib/libc.so.6`, but with Nix, it might
refer to `/nix/store/6yaj...drnn-glibc-2.27/lib/libc.so.6` instead.

See that `/nix/store` path? That's the *Nix store*. The things
stored in there are *immutable* files and directories,
identified by a hash.
Conceptually, the Nix store is similar to the layers used by Docker,
with one big difference: the layers apply on top of each others,
while the files and directories in the Nix store are disjoint;
they never conflict with each other (since each object is stored
in a different directory).

On Nix, "installing a package" means downloading a number
of files and directories in the Nix store, and then setting up a
[profile](https://nixos.org/nix/manual/#sec-profiles) (essentially
a bunch of symlinks so that the programs that we just installed
are now available in our `$PATH`).


### Experimenting with Nix

That sounded very theoretical, right? Let's see Nix in action.

We can run Nix in a container with `docker run -ti nixos/nix`.

Then we can check installed packages with `nix-env --query` or `nix-env -q`.

It will only show us `nix` and `nss-cacert`. Weird, don't we also have,
like, a shell, and many other tools like `ls` and so on? Yes, but in that
particular container image, they are provided by a static `busybox`
executable.

Alright, how do we install something?
We can do `nix-env --install redis` or `niv-env -i redis`.
The output of that command shows us that it's fetching new
"paths" and placing them in the Nix store. It will at least fetch
one "path" for redis itself, and very probably another one for
the glibc. As it happens, Nix itself (as in, the `nix-env` binary
and a few others) also uses the glibc, but it could be a different
version from the one used by redis. If we run e.g. `ls -ld /nix/store/*glibc*/`
we will then see two directories, corresponding to two different versions
of glibc. As I write these lines, I get two versions of `glibc-2.27`:

```
ef5936ea667f:/# ls -ld /nix/store/*glibc*/
dr-xr-xr-x    ... /nix/store/681354n3k44r8z90m35hm8945vsp95h1-glibc-2.27/
dr-xr-xr-x    ... /nix/store/6yaj6n8l925xxfbcd65gzqx3dz7idrnn-glibc-2.27/
```

You might wonder: "Wait, isn't that the *same* version?" Yes and no!
It's the same version number, but it was probably built with slightly
different options, or different patches. Something changed, so from
Nix' perspective, these are two different objects. Just like when we
build the same Dockerfile but change a line of code somewhere,
the Docker builder keeps track of these small differences and gives
us two different images.

We can ask Nix to show us the dependencies of any file in the Nix
store with `nix-store --query --references` or `nix-store -qR`.
For instance, to see the dependencies of the Redis binaries
that we just installed, we can do `nix-store -qR $(which redis-server)`.

In my container, the output looks like this:

```
/nix/store/6yaj6n8l925xxfbcd65gzqx3dz7idrnn-glibc-2.27
/nix/store/mzqjf58zasr7237g8x9hcs44p6nvmdv7-redis-5.0.5
```

Now here comes the kicker. These directories are all we need
to run Redis *anywhere*. Yes, that includes `scratch`. We don't
need any extra library. (Maybe just tweak our `$PATH` for
convenience, but that's not even strictly necessary.)

We can even generalize the process by using a Nix *profile*.
A profile contains the `bin` directory that we need to add to
our `$PATH` (and a few other things; but I'm simplifying for convenience).
This means that if I do, `nix-env --profile myprof -i redis memcached`,
`myprof/bin` will contain the executables for Redis and Memcached.

Even better, profiles are objects in the Nix store as well.
Therefore, I can use that `nix-store -qR` command with them,
to list their dependencies.


### Creating minimal images with Nix

Using the commands that we've seen in the previous section,
we can write the following Dockerfile:

```dockerfile
FROM nixos/nix
RUN mkdir -p /output/store
RUN nix-env --profile /output/profile -i redis
RUN cp -va $(nix-store -qR /output/profile) /output/store
FROM scratch
COPY --from=0 /output/store /nix/store
COPY --from=0 /output/profile/ /usr/local/
```

The first stage uses Nix to install Redis in a new
"profile". Then, we ask Nix to list all the dependencies
for that profile (that's the `nix-store -qR` command)
and we copy all these dependencies to `/output/store`.

The second stage copies these dependencies to
`/nix/store` (i.e. their original location in Nix), and
copies the profile as well. (Mostly because the
profile directory contains a `bin` directory, and we
want that directory to be in our `$PATH`!)

The result is a 35 MB image with Redis *and nothing else*.
If you want a shell, just update the Dockerfile
to have `-i redis bash` instead, and *voilà!*

If you're tempted to rewrite all your Dockerfiles to use this,
wait a minute. First, this image lacks crucial metadata like
`VOLUME`, `EXPOSE`, as well as `ENTRYPOINT` and
the associated wrapper. Next, I have something even better
for you in the next section.


### Nixery

All package managers work the same way: they download (or generate)
files and install them on our system. But with Nix, there is an important difference:
the installed files are immutable by design. When we install
packages with Nix, they don't change what we had before.
Docker layers can affect each other (because a layer can change
or remove a file that was added in a previous layer), but Nix
store objects cannot. 

Have a look at that Nix container that we ran earlier (or start a new one
with `docker run -ti nixos/nix`). In particular, check out `/nix/store`.
There are bunch of directories like these ones:

```
b7x2qjfs6k1xk4p74zzs9kyznv29zap6-bzip2-1.0.6.0.1-bin/
cinw572b38aln37glr0zb8lxwrgaffl4-bash-4.4-p23/
d9s1kq1bnwqgxwcvv4zrc36ysnxg8gv7-coreutils-8.30/
```

If we use Nix to build a container image (like we did in the Dockerfile
at the end of the previous section), all we need is a bunch of
directories in `/nix/store` + a little bundle of symlinks for convenience.

Imagine that we upload each directory of our Nix store as an image
layer in a Docker registry.

Now, when we need to generate an image with packages X, Y, and Z,
we can:
- generate a small layer with the bundle of symlinks
  to easily invoke any programs in X, Y, and Z
  (this corresponds to the last `COPY` line in the Dockerfile above),
- ask Nix what are the corresponding store objects
  (for X, Y, and Z, as well as their dependencies),
  and therefore the corresponding layers,
- generate a Docker image manifest that references
  all these layers.

This is exactly what [Nixery](https://nixery.dev/) is doing.
Nixery is a "magic" container registry that generates container
image manifests on the fly, referencing layers that are Nix
store objects.

In concrete terms, if we do `docker run -ti nixery.dev/redis/memcached/bash bash`,
we get a shell in a container that has Redis, Memcached, and Bash; and the
image for that container is generated on the fly.
(Note that we should rather do `docker run -ti nixery.dev/shell/redis/memcached sh`,
because when an image starts with `shell`, Nixery gives us a few essential
packages on top of the shell; like `coreutils`, for instance.)

There are a few extra optimizations in Nixery; if you're interested,
you can check [this blog post](https://grahamc.com/blog/nix-and-layered-docker-images)
or [that talk from NixConf](https://www.youtube.com/watch?v=pOI9H4oeXqA).


### Other ways to leverage Nix

Nix can also generate container images directly.
There is a pretty good example in [this blog post](https://lethalman.blogspot.com/2016/04/cheap-docker-images-with-nix_15.html).
Note, however, that the technique shown in the blog post
[requires kvm](https://twitter.com/jpetazzo/status/1241741547751845888)
and won't work in most build environments leveraging cloud instances
(except the ones with nested virtualization, which is still very rare) or within containers.
Apparently, you will have to adapt the examples and
[use buildLayeredImage](https://twitter.com/tazjin/status/1241743569888649218)
but I didn't go that far so I don't know how much work that entails.


### To Nix or not to Nix?

In a short (or even not-so-short) blog post like this one, I cannot teach
you how to use Nix "by the book" to generate perfect containers images.
But I could at least demonstrate some basic Nix commands, and show
how to use Nix in a multi-stage Dockerfile to generate a custom container
image in an entirely new way. I hope that these examples will help you
to decide if Nix is interesting for your apps. 

Personally, I look forward to using Nixery when I need ad-hoc container
images, in particular on Kubernetes. Let's pretend, for instance, that I
need an image with `curl`, `tar`, and the AWS CLI. My traditional
approach would have been to use `alpine`, and execute `apk add curl tar py-pip`
and then `pip install awscli`. But with Nixery, I can simply use the image
`nixery.dev/shell/curl/gnutar/awscli`!


## And all the little details

If we use very minimal images (like `scratch`, but also to some extent
`alpine` or even images generated with distroless, Bazel, or Nix),
we can run into unexpected issues. There are some files that we
usually don't think about, but that some programs might expect
to find on a well-behaved UNIX system, and therefore in a
container filesystem.

What files are we talking about exactly? Well, here is a short,
but non-exhaustive list:
- TLS certificates,
- timezone files,
- UID/GID mapping files.

Let's see what these files are exactly, why and when we need
them, and how to add them to our images.


### TLS certificates

When we establish a TLS connection to a remote server
(e.g. by making a request to a web service or API over HTTPS),
that remote server generally shows us its certificate. Generally, that
certificate has been signed by a well-known *certificate authority*
(or CA). Generally, we want to check that this certificate is valid,
and that we know indeed the authority that signed it.

(I say "generally" because there are some very rare scenarios
where either that doesn't matter, or we validate things differently;
but if you are in one of these situations, you should know. If you 
don't know, assume that you *must* validate certificates! Safety first!)

The key (pun not intended) in that process lies in these well-known
certificate authorities. To validate certificates of the servers that we
connect to, we need the certificates of the certificate authorities.
These are typically installed under `/etc/ssl`.

If we are using `scratch` or another minimal image, and we
connect to a TLS server, we might get certificate validation errors.
With Go, these look like `x509: certificate signed by unknown authority`.
If that happens, all we need to do is add the certificates to your image.
We can get them from pretty much any common image like `ubuntu`
or `alpine`. Which one we use isn't important, as they all come with
pretty much the same bundle of certs.

The following line will do the trick:

```dockerfile
COPY --from=alpine /etc/ssl /etc/ssl
```

By the way, this shows that if we want to copy files from an image,
we can use `--from` to refer to that image, even if it's not a build
stage!


### Timezones

If our code manipulates time, in particular *local* time (for instance,
if we display time in local time zones, as opposed to dates or internal
timestamps), we need *timezone files*. You might think: "Wait, what?
If I want to manage timezones, all I need to know is the offset from UTC!"
Ah, but that's without accounting for daylight savings time! Daylight savings
time (DST) is tricky, because not all places have DST. Among places that
have DST, the change between standard time and daylight savings time
doesn't happen at the same date. And over the years, some places
will implement (or cancel) DST, or change the period during which it's
used.

So if we want to display local time, we need files describing all
this information. On UNIX, that's the `tzinfo` or `zoneinfo` files.
They are traditionally stored under `/usr/share/zoneinfo`.

Some images (e.g. `centos` or `debian`) do include timezone files.
Others (e.g. `alpine` or `ubuntu`) do not. The package including
the files is generally named `tzdata`.

To install timezone files in our image, we can do e.g.:

```dockerfile
COPY --from=debian /usr/share/zoneinfo /usr/share/zoneinfo
```

Or, if we're already using `alpine`, we can simply `apk add tzdata`.

To check if timezone files are properly installed, we can run a command
like this one in our container:

```bash
TZ=Europe/Paris date
```

If it shows something like `Fri Mar 13 21:03:17 CET 2020`, we're good.
If it shows `UTC`, it means that the timezone files weren't found.


### UID/GID mapping files

One more thing that our code might need to do: looking up
user and group IDs. This is done by looking up in `/etc/passwd`
and `/etc/group`. Personally, the only scenario where I had
to provide these files was to run desktop applications in containers
(using tools like [clink](https://github.com/soulshake/clink) or
[Jessica Frazelle](https://twitter.com/jessfraz)'s
[dockerfiles](https://github.com/jessfraz/dockerfiles).

If you need to install these files in a minimal container,
you could generate them locally, or in a stage of a multi-stage
container, or bind-mount them from the host (depending on
what you're trying to achieve).

[This blog post](https://medium.com/@chemidy/create-the-smallest-and-secured-golang-docker-image-based-on-scratch-4752223b7324)
shows how to add a user to a build container, and then
copy `/etc/passwd` and `/etc/group` to the run container.



## Conclusions

As you can see, there are many ways to reduce the size of our
images. If you're wondering, “what's the absolute best method
to reduce image size?”, bad news: there isn't an absolute best
method. As usual, the answer is “it depends”.

Multi-stage builds based on Alpine will give excellent results
in many scenarios.

But some libraries won't be available on Alpine, and building
them might require more work than we'd want; so a multi-stage
build using classic distros will do great in that case.

Mechanisms like Distroless or Bazel can be even better, but
require a significant upfront investment.

Static binaries and the `scratch` image can be useful when
deploying in environments with very little space, like
embedded systems.

Finally, if we build and maintain many images (hundreds or more),
we might want to stick to a single technique, even if it's not
always the best. It might be easier to maintain hundreds of image
using the same structure, rather than having a plethora of variants
and some exotic build systems or Dockerfiles for niche scenarios.

If there is a particular technique that you use and that I haven't
mentioned, [let me know!](mailto:jerome.petazzoni@gmail.com?subject=About+your+minimage+blog+post)
I'd love to learn it.

### Thanks and acknowledgements

The inspiration to write this series of articles came from [that specific tweet](https://twitter.com/ellenkorbes/status/1216458929636630533) by [@ellenkorbes](https://twitter.com/ellenkorbes). When I deliver container training, I always spend some time explaining how to reduce the size of images, and I often go on fairly long tangents about dynamic vs static linking; and sometimes, I wonder if it's really necessary to mention all these little details. When I saw L's tweet and some of the responses to that tweet, I thought, "wow, I guess it might actually help a lot of people if I wrote down what I know about this!". Next thing you know, I woke up next to an empty crate of Club Mate and three blog posts! 🤷🏻 If you are looking for amazing resources about running Go code on Kubernetes (and other adjacent topics), I strongly recommend that you check out L's [list of talks](http://ellenkorbes.com/#talks). In particular, [The Quest For The Fastest Deployment Time](https://www.youtube.com/watch?v=E8JgnAYWSvA&feature=youtu.be) will be super relevant if you're working with Kubernetes and want to reduce the time between "saving my code in my editor" and "seeing these changes live on my Kubernetes cluster". If you liked my blog posts, you will probably enjoy L's presentation too. (There is also a [Portuguese version of that talk](https://www.youtube.com/watch?v=itzm_ZNN74s) on [FiqueEmCasaConf](https://www.youtube.com/playlist?list=PLf-O3X2-mxDmn0ikyO7OF8sPr2GDQeZXk).)

Much thanks to the folks who reached out to suggest improvements and additions! In particular:
- [David Delabassée](https://twitter.com/delabassee) for Java advice and `jlink`;
- [Sylvain Rabot](https://twitter.com/sylr) for certificates, timezones, and UID and GID files;
- [Gleb Peregud](https://twitter.com/gleber) and [Vincent Ambo](https://twitter.com/tazjin)
  for sharing very useful resources on Nix.

These posts were initially written in English, and the English version was proofread by [AJ Bowen](https://twitter.com/s0ulshake), who caught many typos, mistakes, and pointed out many ways to improve my prose. All remaining errors are mine and mine only. AJ is currently working on a project involving historical preservation of ancient postcards, and if that's your jam, you should totally subscribe [here](https://www.ephemerasearch.com/) to know more.

The French version was translated by [Aurélien Violet](https://twitter.com/brimstone75) and  [Romain Degez](https://twitter.com/rdegez). If you enjoyed reading the French version, make sure that you send them a big *thank you* because this represented a lot more work than it seems!
