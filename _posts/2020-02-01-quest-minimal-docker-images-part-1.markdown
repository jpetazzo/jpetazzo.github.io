---
title: "The Quest for Minimal Docker Images, part 1"
layout: post
---

When getting started with containers, it's pretty easy to
be shocked by the size of the images that we build.
We're going to review a number of techniques to reduce image
size, without sacrificing developers' and ops' convenience.
In this first part, we will talk about multi-stage builds,
because that's where anyone should start if they want to
reduce the size of their images. We will also
explain the differences between static
and dynamic linking, as well as why we should care about that.
This will be the occasion to introduce Alpine.

In the [second part], we will see some particularities
relevant to various popular languages. We will talk about
Go, but also Java, Node, Python, Ruby, and Rust.
We will also talk more about Alpine and how to leverage it
across the board.

In the [third part], we will cover some patterns (and anti-patterns!)
relevant to most languages and frameworks, like using
common base images, stripping binaries and reducing asset size.
We will wrap up with some more exotic or advanced methods
like Bazel, Distroless, DockerSlim, or UPX. We will see how
some of these will be counter-productive
in some scenarios, but might be useful in others.

Note that the sample code and all the Dockerfiles mentioned
here are available in a public GitHub repository,
with a Compose file to build all the images and easily compare
their sizes.

→ [https://github.com/jpetazzo/minimage](https://github.com/jpetazzo/minimage)

{% include minimal_docker_header.markdown %}


## What we're trying to solve

Many people building their first Docker images that compile
some code are unpleasantly surprised by the resulting image sizes.

Look at this trivial "hello world" program in C:

```c
/* hello.c */
int main () {
  puts("Hello, world!");
  return 0;
}
```

We could build it with the following Dockerfile:

```dockerfile
FROM gcc
COPY hello.c .
RUN gcc -o hello hello.c
CMD ["./hello"]
```

... But the resulting image will be more than 1 GB, because it
will have the whole `gcc` image in it!

If we use e.g. the Ubuntu image, install a C compiler, and build
the program, we get a 300 MB image; which looks better, but is
still *way too much* for a binary that, by itself, is less than 20 kB:

```
$ ls -l hello
-rwxr-xr-x   1 root root 16384 Nov 18 14:36 hello
```

Same story with the equivalent Go program:

```go
package main

import "fmt"

func main () {
  fmt.Println("Hello, world!")
}
```

Building this code with the `golang` image, the resulting image
is 800 MB, even though the `hello` program is only 2 MB:

```
$ ls -l hello
-rwxr-xr-x 1 root root 2008801 Jan 15 16:41 hello
```

There has to be a better way!

Let's see how to drastically reduce the size of these images.
In some cases, we can achieve 99.8% size reduction (but we will
see that it's not always a good idea to go that far).

Pro tip: to easily compare the size of our images, we are going
to use the same image name, but different tags. For instance, our
images will be `hello:gcc`, `hello:ubuntu`, `hello:thisweirdtrick`,
etc. That way, we can run `docker images hello` and it will list
all the tags for that `hello` image, with their sizes, without
being encumbered with the bazillions of other images that we have
on our Docker engine.


## Multi-stage builds

This is the first (and most drastic) step we can take to reduce the
size of our images. We need to be careful, though, because if
it's done incorrectly, it can result in images that are harder
to operate (or could even be completely broken).

Multi-stage builds come from a simple idea: "I don't need
to include the C or Go compiler and the whole build toolchain
in my final application image. I just want to ship the binary!"

We obtain a multi-stage build by adding another `FROM` line in
our Dockerfile. Look at the example below:

```dockerfile
FROM gcc AS mybuildstage
COPY hello.c .
RUN gcc -o hello hello.c
FROM ubuntu
COPY --from=mybuildstage hello .
CMD ["./hello"]
```

We use the `gcc` image to build our `hello.c` program. Then,
we start a new stage (that I will call the "run stage")
using the `ubuntu` image. We copy the `hello`
binary from the previous stage. The final image is 64 MB instead of 1.1 GB, so that's about 95% size reduction:

```
$ docker images minimage
REPOSITORY          TAG                    ...         SIZE
minimage            hello-c.gcc            ...         1.14GB
minimage            hello-c.gcc.ubuntu     ...         64.2MB
```

Not bad, right? We can do even better. But first, a few tips and warnings.

You don't have to use the `AS` keyword when declaring your build
stage. When copying files from a previous stage, you can simply
indicate the number of that build stage (starting at zero).

In other words, the two lines below are identical:

```dockerfile
COPY --from=mybuildstage hello .
COPY --from=0 hello .
```

Personally, I think it's fine to use numbers for build stages
in short Dockerfiles (say, 10 lines or less), but as soon as
your Dockerfile gets longer (and possibly more complex, with
*multiple* build stages), it's a good idea to name the stages
explicitly. It will help maintenance for your team mates
(and also for future you who will review that Dockerfile months
later).


### Warning: use classic images

I strongly recommend that you stick to classic images for your "run"
stage. By "classic", I mean something like CentOS, Debian, Fedora,
Ubuntu; something familiar. You might have heard about Alpine and
be tempted to use it. Do not! At least, not yet. We will talk about
Alpine later, and we will explain why we need to be careful with it.


### Warning: `COPY --from` uses absolute paths

When copying files from a previous stage, paths are
interpreted as relative to the root of the previous stage.

The problem appears as soon as we use a builder image
with a `WORKDIR`, for instance the `golang` image.

If we try to build this Dockerfile:

```dockerfile
FROM golang
COPY hello.go .
RUN go build hello.go
FROM ubuntu
COPY --from=0 hello .
CMD ["./hello"]
```

We get an error similar to the following one:

```
COPY failed: stat /var/lib/docker/overlay2/1be...868/merged/hello: no such file or directory
```

This is because the `COPY` command tries to copy `/hello`, but since
the `WORKDIR` in `golang` is `/go`, the program path is really
`/go/hello`.

If we are using official (or very stable) images in our build,
it's probably fine to specify the full absolute path and forget
about it.

However, if our build or run images might change in the future,
I suggest to specify a `WORKDIR` in the build image. This will
make sure that the files are where we expect them, even if the
base image that we use for our build stage changes later.

Following this principle, the Dockerfile to build our Go program
will look like this:

```dockerfile
FROM golang
WORKDIR /src
COPY hello.go .
RUN go build hello.go

FROM ubuntu
COPY --from=0 /src/hello .
CMD ["./hello"]
```

If you're wondering about the efficiency of multi-stage builds
for Golang, well, they let us go (no pun intended)
from a 800 MB image down to a 66 MB one:

```
$ docker images minimage
REPOSITORY     TAG                              ...    SIZE
minimage       hello-go.golang                  ...    805MB
minimage       hello-go.golang.ubuntu-workdir   ...    66.2MB
```
Not bad!

## `FROM scratch`

Back to our "Hello World" program. The C version is 16 kB,
the Go version is 2 MB. Can we get an image of that size?

Can we build an image with *just our binary and nothing else?*

Yes! All we have to do is use a multi-stage build, and pick
`scratch` as our run image (with some caveats, which we’ll see shortly). `scratch` is a virtual image.
You can't pull it or run it, because it's completely empty.
This is why if a Dockerfile starts with `FROM scratch`, it
means that we're building *from scratch*, without using any
pre-existing ingredient.

This gives us the following Dockerfile:

```dockerfile
FROM golang
COPY hello.go .
RUN go build hello.go

FROM scratch
COPY --from=0 /go/hello .
CMD ["./hello"]
```

If we build that image, its size is exactly the size of
the binary (2 MB), and it works!

There are, however, a few things to keep in mind when using
`scratch` as a base.


### No shell

The `scratch` image doesn't have a shell. This means that we
cannot use the *string syntax* with `CMD` (or `RUN`, for that
matter). Consider the following Dockerfile:

```dockerfile
...
FROM scratch
COPY --from=0 /go/hello .
CMD ./hello
```

If we try to `docker run` the resulting image, we get the following
error message:

```
docker: Error response from daemon: OCI runtime create failed:
container_linux.go:345: starting container process caused
"exec: \"/bin/sh\": stat /bin/sh: no such file or directory": unknown.
```

It's not presented in a very clear way, but the core information
is here: `/bin/sh` is missing from the image.

This happens because when we use the *string syntax* with `CMD`
or `RUN`, the argument gets passed to `/bin/sh`. This means
that our `CMD ./hello` above will execute `/bin/sh -c "./hello"`,
and since we don't have `/bin/sh` in the `scratch` image, this fails.

The workaround is simple: use the *JSON syntax* in the Dockerfile.
`CMD ./hello` becomes `CMD ["./hello"]`. When Docker detects
the JSON syntax, it runs the arguments directly, without a shell.


### No debugging tools

The `scratch` image is, by definition, empty; so it doesn't have
*anything* to help us troubleshoot the container. No shell
(as we said in the previous paragraph) but also no `ls`, `ps`,
`ping`, and so on and so forth. This means that we won't be able
to enter the container (with `docker exec` or `kubectl exec`)
to look around.

(Strictly speaking, there are some methods to troubleshoot
our container anyway. We can use `docker cp` to get files out of the
container; we can use `docker run --net container:` to interact with
the network stack; we can interact with the container's processes
with `docker run --pid container:` or even directly from the host;
similarly, we can enter the container's various namespaces with
a low-level tool like `nsenter`.
Recent versions of Kubernetes have the concept of [ephemeral container](
https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/),
though it's still in alpha. So let's keep in mind that while
these techniques are available,
they will definitely make our lives more complicated,
especially when we have so much to deal with already!)

One workaround here is to use an image like `busybox` or `alpine`
instead of `scratch`. Granted, they're bigger (respectively 1.2 MB
and 5.5 MB), but in the grand scheme of things, it's a small price
to pay if we compare it to the hundreds of megabytes, or even gigabytes,
of our original image.


### No libc

This one is trickier to troubleshoot. Our simple "hello world"
in Go worked fine, but if we try to put a C program in the `scratch`
image, or a more complex Go program (for instance, anything using
network packages), we will get the following error message:

```
standard_init_linux.go:211: exec user process caused "no such file or directory"
```

Some file seems to be missing.
But it doesn't tell us *which* file is missing exactly.

The missing file is a *dynamic library* that is necessary
for our program to run.

What's a *dynamic library* and why do we need it?

After a program is compiled, it gets *linked* with the libraries
that it is using. (As simple as it is, our "hello world" program
is still using libraries; that's where the `puts` function comes
from.) A long time ago (before the 90s), we used mostly
*static linking*, meaning that all the libraries used by a program
would be included in the binary. This is perfect when software
is executed from a floppy disk or a cartridge, or when there is
simply no standard library. However, on a timesharing system like
Linux, we run many concurrent programs that are stored on a hard
disk; and these programs almost always use the standard C library.
In that scenario, it gets more advantageous
tu use *dynamic linking*. With dynamic linking, the final
binary doesn't contain the code of all the libraries that it uses.
Instead, it contains references to these libraries, like
"this program needs functions `cos` and `sin` and `tan` from
`libtrigonometry.so`". When the program is executed, the system
looks for that `libtrigonometry.so` and loads it alongside the
program so that the program can call these functions.

Dynamic linking has multiple advantages.

1. It saves disk space, since common libraries don't have
   to be duplicated anymore.
2. It saves memory, since these libraries can be loaded once
   from disk, and then shared between multiple programs using them.
3. It makes maintenance easier, because when a library is updated,
   we don't need to recompile all the programs using that library.

(If we want to be thorough, memory savings aren't a result
of *dynamic libraries* but rather of *shared libraries*.
That being said, the two generally go together. On Linux, dynamic library files typically have the extension
`.so`, which stands for *shared object*. On Windows, it's `.DLL`,
which stands for [Dynamic-link library](https://en.wikipedia.org/wiki/Dynamic-link_library).)

Back to our story: by default, C programs are *dynamically linked*.
(This is also the case for Go programs that are using certain packages.)
Our specific program uses the standard C library, which on
recent Linux systems will be in `libc.so.6`. So in order to run, our
program needs that file to be present in the container image.
And if we're using `scratch`, that file is obviously absent.

(Same thing if we use `busybox` or `alpine`, because `busybox`
doesn't contain a standard library, and `alpine` is using another
one, which is incompatible. We'll talk more about that later.)

How do we solve this?

There are at least 3 options.


### Building a static binary

We can tell our toolchain to make a static binary. There are
various ways to achieve that (depending on how we build our
program in the first place), but if we're using `gcc`, all we
have to do is add `-static` to the command line:

```bash
gcc -o hello hello.c -static
```

The resulting binary is now 760 kB (on my system) instead of
16 kB. Of course, we're embedding the library in the binary,
so it's much bigger. But that binary will now run correctly
in the `scratch` image.

We can get an even smaller image if we build a static
binary *with Alpine*. We will talk more about Alpine in the
next article; but just for information,
the result would be less than 100 kB!


### Adding the libraries to our image

We can find out which libraries our program needs with the
`ldd` tool:

```
$ ldd hello
    linux-vdso.so.1 (0x00007ffdf8acb000)
    libc.so.6 => /usr/lib/libc.so.6 (0x00007ff897ef6000)
    /lib64/ld-linux-x86-64.so.2 => /usr/lib64/ld-linux-x86-64.so.2 (0x00007ff8980f7000)
```

We can see the libraries needed by the program and their paths
(as resolved by the linker).

In the example above, the only "real" library is `libc.so.6`.
`linux-vdso.so.1` is related to a mechanism called [VDSO
(virtual dynamic shared object)](https://en.wikipedia.org/wiki/VDSO),
which accelerates some system calls.
Let's pretend it's not there. As for `ld-linux-x86-64.so.2`,
it's actually the dynamic linker itself.
(Technically, our `hello` binary contains information
saying, "hey, this is a dynamic program, and the thing
that knows how to put all its parts together is `ld-linux-x86-64.so.2`".)

*If we were so inclined,* we could manually add all the
files listed above by `ldd` to our image. It would be
fairly tedious, and difficult to maintain, especially
for programs with lots of dependencies. For our little
hello world program, this would work fine. But for a more
complex program, for instance something using DNS, we would
run into another issue. The GNU C library (used on most Linux
systems) implements DNS (and a few other things) through
a fairly complex mechanism called the *Name Service Switch*
(NSS in short). This mechanism needs a configuration file,
`/etc/nsswitch.conf`, and additional libraries. But these
libraries don't show up with `ldd`, because they are loaded
later, when the program is running. If we want DNS resolution
to work correctly, we still need to include them!
(These libraries are typically found at `/lib64/libnss_*`.)

I personally can't recommend going that route, because it is
quite arcane, difficult to maintain, and it might easily break
in the future.


### `busybox:glibc`

There is an image designed specifically to solve all these
issues: `busybox:glibc`. It is a small image (5 MB) using
`busybox` (so providing a lot of useful tools for troubleshooting
and operations) and providing the GNU C library (or `glibc`).
That image contains precisely all these pesky files that
we were mentioning earlier. This is what we should use if
we want to run a dynamic binary in a small image.

Keep in mind, however, that if our program uses additional
libraries, those will need to be copied as well.


## Recap and (partial) conclusion

Let's see how we did for our "hello world" program in C.
*Spoiler alert:* this list includes results obtained
by leveraging Alpine in ways that will be described
in the next part of this series.

- Original image built with `gcc`: 1.14 GB
- Multi-stage build with `gcc` and `ubuntu`: 64.2 MB
- Static glibc binary in `alpine`: 6.5 MB
- Dynamic binary in `alpine`: 5.6 MB
- Static binary in `scratch`: 940 kB
- Static musl binary in `scratch`: 94 kB

That's a 12000x size reduction, or 99.99% less disk space (and network usage).

*Not bad.*

Personally, I wouldn't go with the `scratch` images
(because troubleshooting them might be, well, trouble)
but if that's what you're after, they're there for you!

In the [second part], we will mention some aspects specific
to the Go language, including cgo and tags. We will also
cover other popular languages, and we will talk more
about Alpine, because it's pretty awesome if you ask me.

