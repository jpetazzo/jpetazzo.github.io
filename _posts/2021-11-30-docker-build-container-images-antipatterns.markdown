---
layout: post
title: "Anti-Patterns When Building Container Images"
---

This is a list of recurring anti-patterns that I see when
I help folks with their container build pipelines,
and suggestions to avoid them or refactor them into
something better.

And since [only a Sith deals in absolutes], keep in mind
that these anti-patterns aren't always bad.

Many of them are harmless when used separately.
But when combined,
they can easily compromise your productivity
and waste time and resources, as we will see.


## Big images

It's better to have smaller images, because they will generally be
faster to build, push and pull, 
use less disk space and network.

But how big is big?

For microservices with relatively few dependencies, I don't worry
about images below 100 MB. For more complex
workloads (monoliths or, say, data science apps), it's fine to have
images up to 1 GB. Above that, I would start to investigate.

I wrote a series of blog posts about optimizing the size of your
images ([part 1], [part 2], [part 3]), so I'm not going to repeat
that here; instead, let's focus on some exceptions to the rule.


### All-in-one mega images

Sometimes you need Node, PHP, Python, Ruby, and a few database
engines in your image, as well as hundreds of libraries, because
your image will be used as a base for a PAAS or CI platform.
This is the case on platforms that have just *one* available
image to run all apps and all jobs; then the image needs to
have everything installed, of course.

I don't have magic solutions for this. Keep in mind that you
will probably need to support multiple images anyway eventually,
so when you introduce support for, say, version selection,
you might want to allow selection of smaller images with a tighter
focus. Just an idea!


### Data sets

Some code (especially in data science) needs a data set to function.
It could be a reference genome, a machine learning model, a huge graph
on which we'll do some computation...

It's tempting to put the dataset in the image, so that the container
can "just work" no matter where and how we run it.
And if the dataset is small, that's generally fine.

But if the data set is big (let's say, more than 1 GB) it will start
becoming a problem. Sure, if your Dockerfile is well organized, the
model will be added before the code; but if you add the model *after*
the code, it will be a catastrophe. Builds will be slow, use up a lot
of disk space, and if code must be tested on remote machines (as opposed
to locally), the model will be pushed/pulled every time and use a lot
of disk space on the remote machines too. That's *very bad*.

Instead, consider **mounting the data set from a volume.**
Assume that your code can access the data it needs on, say, `/data`.

When you run locally with a tool like Compose, you can use a
bind-mount from a local directory (which will act as a cache)
and a separate container to load the data. The Compose file would
look like this:

```yaml
services:
  data-loader:
    image: nixery.dev/shell/curl
    volumes:
    - ./data:/data
    command: |
      if ! [ -f /data/dataset ]; then
        curl ... -o /data/dataset
        touch /data/ready
      fi
  data-worker:
    build: worker
    volumes:
    - ./data:/data
    command: |
      while ! [ -f /data/ready ]; do sleep 1; done
      exec worker     
```

The `data-worker` will wait for the data to be available before
starting, and `data-loader` will download the data to the local
directory `data`. It will download it only once. If you need
to download the data again, just delete that directory and run again.

Now, when running e.g. on Kubernetes, we can leverage an `initContainer`
to download the data, with a Pod spec similar to this:

```yaml
spec:
  volumes:
  - name: data
  initContainers:
  - name: data-loader
    image: nixery.dev/curl
    volumeMounts:
    - name: data
      mountPath: /data
    command:
    - curl
    - ...
    - -o
    - /data/dataset
  containers:
  - name: data-worker
    image: .../worker
    volumeMounts:
    - name: data
      mountPath: /data
```

Note that the worker container doesn't need to wait for the data
to be loaded, since Kubernetes will start it only after the
`initContainer` is done.

If we run multiple workers per node, we can also use a `hostPath`
volume (instead of an ephemeral `emptyDir` volume) so that the
data only gets loaded once.

Another option is to leverage a DaemonSet to automatically populate
that data directory on every node of the cluster ahead of time.

The best option depends on your particular use case. Do you have a single,
big data set? Multiple ones? How often do they change?

The big upside is that your images will be much smaller, and they will
still behave identically in local environments and in remote clusters,
without requiring you to add special code to download or manage the model
in your app logic. Big win!


## Small images

It's also possible to have images that are *too small*. Wait, what's wrong
with an image that would just be 5 MB?

Nothing wrong with the size of the image, but if it's so small, it might
be missing some useful tools, and that might cost you and your colleagues
a lot of time when troubleshooting the image.

Images built with [distroless] or with `FROM scratch` might be small, but
if your team is regularly stumped because they can't even get a shell
in the image to e.g. check which version of a particular file is there,
see running processes with `ps`, or network connections with `netstat` or
`ss`, what's the point?

⚠️ This is extremely context-dependent. Some teams never need to get a
shell in an image. Or, if you use Docker, you can use `docker cp` to copy
some static tools (e.g. busybox) to a running container and check what's
going on. Or, if you're working with local images, you can easily rebuild
your image and add the tools that you need. Or, if you're running on
Kubernetes, you can enable the [ephemeral containers] alpha feature.
But on most production Kubernetes clusters, you won't have access to the
underlying container engine and you may not be able to enable alpha
features, so...

Here is one way to add a very basic toolkit to an existing image.
This example shows a distroless image but it should work with other
images as well:

```dockerfile
FROM gcr.io/distroless/static-debian11
COPY --from=busybox /bin/busybox /busybox
SHELL ["/busybox", "sh", "-c"]
RUN /busybox --install
```

If you want more tools, there is a very elegant way to leverage
[Nixery] and install your tools without clobbering the existing image.
For code deployed on Kubernetes, it's even possible to add the tools
in a volume, so that you don't need to rebuild and redeploy a new image.
If you're interested, let me know, and I'll write a follow-up post
about that!

Overall, I personally like to build on top of Alpine images, because
they're tiny (Alpine is 5 MB) and once you have Alpine you can `apk add`
whatever you want when you need it. Network traffic acting up? Install
`tcpdump` and `ngrep`. Need to JSON stuff in and out? `curl` and `jq`
to the rescue!

Bottom line: small images are generally good, and [distroless] is
honestly some pretty awesome sauce *in the right circumstances.*
If your circumstances are "I can't get in my container and I'm resorting
to adding `print()` statements to my code and pushing it all the way through
CI to staging because I can't `kubectl exec ls`", you might want to reconsider.
Just saying!

## Zip, tar, and other archives

*(Added December 15th, 2021.)*

It is *generally* a bad idea to add an archive (zip, tar.gz or otherwise)
to a container image. It is certainly a bad idea if the container
unpacks that archive when it starts, because it will waste time and
disk space, without providing any gain whatsoever!

It turns out that Docker images are already compressed when they
are stored on a registry and when they are pushed to, or pulled from,
a registry. This means two things:

- storing compressed files in a container image doesn't take less space,
- storing uncompressed files in a container image doesn't use more space.

If we include an archive (e.g. a tarball) and decompress it when the
container starts:

- we waste time and CPU cycles, compared to a container image where the data would
  already be uncompressed and ready to use;
- we waste disk space, because we end up storing both the compressed and
  uncompressed data in the container filesystem;
- if the container runs multiple times, we waste more time, CPU cycles,
  and disk space each time we run an additional copy of the container.

If you notice that a Dockerfile is copying an archive, it is almost
always better to uncompress the archive (e.g. using a multi-stage
build) and copy the uncompressed files.

## Rebuilding common bases

It's pretty common to have a common base image shared between multiple
apps, or multiple components within the same app. Especially when you
have a bunch of non-trivial dependencies and they take a while to build;
it sounds like a good idea to shove them in a base image, and reference
that image from our other images.

If that image takes a long time to build (say, more than a few minutes),
I recommend that you store that base image in a registry, and instead
of building it locally, pull it from that registry.

Why?

Reason #1: pulling an image is almost always faster than building it.
(Yes, there are exceptions, but trust me, they're pretty rare.)

Reason #2: since this is the base on top of which everything else
gets build, you probably want to make sure that you have a very
specific set of versions in that image; otherwise we're back to
problems like "works on my machine" - exactly what we were trying
to avoid by using containers! If everyone rebuilds the base image locally,
we need to be extra careful about making that build process deterministic
and reproducible: pinning all versions; checking the hashes of all
downloads; using `&&` or `set -e` in all the appropriate places
to abort immediately if something fails within a list of commands in the build process.
Or, we can simply store the base image in a registry, and now we're
sure that everyone is using the same one. Done.

What if we need to tweak that base image, though? Is there an easy
way to do that without pushing a new version of the base image
(which shouldn't be necessary if we only need it locally),
or without editing Dockerfiles?

If you're using Compose, here is an example of a [foundation image pattern].
It's a very simple pattern (I don't think it'll blow your mind!)
but I often see it reimplemented with shell scripts, Makefiles,
and other tools, so I thought it could be useful to show that
it's possible to do it with just Compose. If you build one of your
apps, it will pull the base image; but if you need a custom base
image, you can rebuild that specific image separately with `docker-compose build`.


## Building from the root of a giant monorepo

I don't have strong opinions for or against monorepos, but if your
code lives in a monorepo, you probably have different subdirectories
corresponding to different services and containers.

For instance:

```
monorepo
├── app1
│   └── source...
└── app2
    └── source...
```

One possibility is to put the Dockerfiles at the root of the
repository (or in their own, separate subdirectory), for instance
like this:

```
monorepo
├── app1
│   └── source...
├── app2
│   └── source...
├── Dockerfile.app1
└── Dockerfile.app2
```

We can then build each service with e.g. `docker build . -f Dockerfile.app1`.
The problem with this approach is that if we use the "old" Docker builder
(not BuildKit), the first thing that it does is *upload the entire repo
to the Docker Engine*. If you have a giant 5 GB repo, Docker will copy 5 GB
*at the beginning of each build*, even if your Dockerfile is otherwise
well-designed and leverages caching perfectly.

I prefer to have Dockerfiles in each subdirectory, so that
they can be built independently, in a small and isolated context:

```
monorepo
├── app1
│   ├── Dockerfile
│   └── source...
└── app2
    ├── Dockerfile
    └── source...
```

We can then go to directories `app1` or `app2` and run `docker build .`,
and it will only need the content of that subdirectory.

However, sometimes, the build process needs dependencies that live outside
of the application directory; for instance some shared code in the `lib`
subdirectory below:

```
monorepo
├── app1
│   └── source...
├── app2
│   └── source...
└── lib
    └── source...
```

What should we do in this situation?

Solution #1: package the dependencies in their own images.
When building the images for `app1` and `app2`, instead of
copying that `lib` directory from the repository, copy it
from a `lib` image or a common base image. Of course, this
may or may not be relevant in your situation, because one
of the main selling points of monorepos is that a particular
commit can describe exactly which version of the code and
its dependencies we are using; and this solution can break that.

Solution #2: use BuildKit. BuildKit doesn't need to copy the entire
build context, so it will be much more efficient in that scenario.

Let's talk more about BuildKit in that context!


## Not using BuildKit

BuildKit is a new backend for `docker build`. It's a complete
rehaul with a ton of new features, including parallel builds,
cross-arch builds (e.g. building ARM images on Intel and vice versa),
building images in Kubernetes Pods, and much more;
while remaining fully compatible with the existing
Dockerfile syntax. It's like switching to a fully electric car:
we still drive it with a wheel and two pedals, but internally
it is completely different from the old thing.

If you are using a recent version of Docker Desktop, you are
probably already using BuildKit, so that's great. Otherwise
(in particular, if you're on Linux), set the environment variable
`DOCKER_BUILDKIT=1` and run your `docker build` or `docker-compose`
command; for instance:

```bash
DOCKER_BUILDKIT=1 docker build . --tag test
```

If you end up liking the result (and I'm pretty confident that you will),
you can set that variable in your shell profile.

“How do I know if I'm using BuildKit?”

Build output *without* BuildKit:
```
Sending build context to Docker daemon  529.9kB
Step 1/92 : FROM golang:alpine AS builder
 ---> cfd0f4793b46
...
Step 90/92 : RUN (     ab -V ...
 ---> Running in 645af9563c4d
Removing intermediate container 645af9563c4d
 ---> 0972a40bd5bb
Step 91/92 : CMD   if tty >/dev/null; then ...
 ---> Running in 50226973af9f
Removing intermediate container 50226973af9f
 ---> 2e963346566b
Step 92/92 : EXPOSE 22/tcp
 ---> Running in e06a628465b3
Removing intermediate container e06a628465b3
 ---> 37d860630477
Successfully built 37d860630477
```
- starts with "Sending build context..." (in this case, more
  than 500 kB)
- needs to transfer the entire build context at each build
- text output is mostly in black and white, except the standard
  error output of the build stages which is in red
- every line of the Dockerfile corresponds to a "step"
- every line of the Dockerfile generates an intermediary image
  (the `---> xxx` that we see in the output)
- execution is linear (92 steps for this image and all its stages)
- build time for this image: 3 minutes, 40 seconds

Build output for the same Dockerfile, *with* BuildKit:
```
 => [internal] load build definition from Dockerfile                                           0.0s
 => => transferring dockerfile: 8.91kB                                                         0.0s
 => [internal] load .dockerignore                                                              0.0s
 => => transferring context: 2B                                                                0.0s
 => [internal] load metadata for docker.io/library/golang:alpine                               0.0s
...
 => [stage-19 27/28] COPY setup-tailhist.sh /usr/local/bin                                     0.0s
 => [stage-19 28/28] RUN (     ab -V | head -n1 ;    bash --version | head -n1 ;    curl --ve  0.7s
 => exporting to image                                                                         2.0s
 => => exporting layers                                                                        2.0s
 => => writing image sha256:9bd0149e04b9828f9e0ab2b09222376464ee3ca00a2de0564f973e2f90e0cfdb   0.0s
```
- starts with a few `[internal]` lines and only transfers what it needs
  from the build context
- can cache parts of the build context across builds
- text output is mostly dark blue
- Dockerfile commands like `RUN` and `COPY` do produce new steps,
  but other commands (like the `EXPOSE` and `CMD` at the end) do not
- each step generates a layer, but no intermediary images
- execution is parallelized when possible, using a dependency graph
  (the final image is the 28th step of the 19th stage of that Dockerfile)
- build time for this image: 1 minute, 30 seconds

So make sure that you're using BuildKit: I can't think of any downside.
It should never be slower, and in many cases, it will make your builds
much faster.


## Requiring rebuilds for every single change

That's another anti-pattern. Granted, if you use a compiled language,
and want to run the code in containers, you might have to rebuild
each time you make a code change.

But if you're using an interpreted language, or if you're working on
static files or templates, it shouldn't be necessary to rebuild images
(and recreate containers) after each change.

Most of the development workflows that I see are using correctly
volumes, or [live update] with tools like Tilt; but once in a while,
I see someone with e.g. generated Python code, or re-running webpack
completely after each change (instead of using the webpack dev server),
for instance.

(By the way, if you try to deploy your changes to a development
Kubernetes cluster *really fast*, you should absolutely check
[Ellen Körbes]' [Quest for the Fastest Deployment Time] ([video](https://www.youtube.com/watch?v=9C9BKzyZG_Y) and [slides](https://s3.amazonaws.com/bizzabo.file.upload/wieCUWlZTBKV3mWlKh3D_L%20K%C3%B6rbes%20-%20The%20Fastest%20Deployment%20Time.pdf)).
Spoilers, I have enough fingers on one hand to count the seconds
between "Save my Go code in my editor" and "that code is now
running on my remote Kubernetes clusters". 💯)

Again, that anti-pattern is not always a big deal.
If your build only takes a couple of seconds
and the new layers are just a few megabytes, it's probably alright
if you rebuild and recreate containers all the time.


## Using custom scripts instead of existing tools

We've all done it: the good old `./build.sh` (or `build.bat`).
More than two decades ago, when I was doing my bachelor's degree
in computer science, most of my C homework assignments were built
with a crappy shell script instead of a Makefile. Not because I
didn't know about Makefiles, but because we worked on both Linux
and HP/UX and I kept finding creative ways to shoot myself in the
foot with subtle differences between their respective implementations
of `make`. (This might be why I tend to stay away from bashisms today,
when I can.)

There are many tools out there providing outstanding developer
experience. Compose, Skaffold, Tilt, just to name a few.
They have excellent documentations and tutorials, and are
used by thousands of developers out there. Some of your developers
already know them and know how to maintain Compose files or Tiltfiles.

If our homemade deployment script is just about 10 lines,
it's not doing anything complicated, and can be replaced
by a Compose file or Tiltfile. (Keep in mind that if it's
using any external tool like Terraform or a cloud CLI, we
need to make sure that this is installed, which will always
be at least as much work as "git clone ; docker-compose up".)

If our homemade deployment script is about 100 lines,
it might be doing something more complex. Building an image
and then pushing it and then kicking a CI job and then
provisioning a staging cluster to test that image, obtaining
the address of the cluster to inject it in a local client;
that kind of thing; handling many variations and special cases.
If it's 100 lines, there can't be *that* many variations,
and we're exactly at the point where everyone will start
adding their own particular special case to the script,
slowly taking us to the next stage.

If our homemade deployment script has a thousand lines
or more, it probably has a lot of custom logic in it,
and handles a lot of situations; that's great! It also means
that it now requires you to write documentation, tests, and
maybe even run internal training for new hires.
Unfortunately, in my experience, these scripts are at least 10x bigger
(often more like 100x) than an equivalent Compose file
or Tiltfile. They have more bugs, less features, and
nobody outside your team or organization knows how to use them.

If you work with one of these bigger deployment scripts,
my suggestion is to try to *remove* rather than *add* code to it.
Move the really custom parts to independent, standalone scripts
that can run equally well locally or in containers.
Replace the non-custom parts with standard tooling.
It's easier to maintain many small scripts rather than a big one.

“But we want to hide the complexity of containers / Docker / Kubernetes
from our developers!”

You do you; but I think the best way to empower developers is
to hide that complexity *behind standard tools*, because when
they need to dive into the tooling, they can tap into a rich ecosystem
instead of having to rely on your internal tooling or platform team.


## Forcing things to run in containers

I like running all my stuff in containers, but I think it's
a very bad idea to *force* folks to run things in containers.

Let's say that we have a script that uses the `gcloud` CLI,
Terraform, and a few other tools like `crane` and `jq`.

On most platforms, these tools are easy to install with your
preferred package manager. The script should therefore be
able to run locally.

But to make things easier for our developers (and make sure
that we use up-to-date versions of these tools),
we build a container image with all these tools.
Instead of running the script directly, we tell our devs to use that image.

At first, it looks like this just means replacing
`yadda-deploy.sh` with `docker run yadda-image`.
In practice, we will need to expose some env vars,
bind-mount some volumes for credentials and code.
We might end up writing a new `yadda-deploy.sh` script
(that will do the `docker run` behind the scenes).
And that's where we can hit trouble.

Compare these two options:

Method #1: to do this task, run the script `yadda-deploy.sh`. This script
requires tools X, Y, and Z to be installed. If you don't want to install
these tools locally, you can run that script in a container by using
image `yadda/deploy` (built using the Dockerfile in this subdirectory)
and the following `docker` or `docker-compose` command: ...

Method #2: to do this task, run the script `yadda-deploy.sh`.
This script requires Docker to be installed.

At first, method #2 seems better, and that's why so many teams
go this route. Look, it's shorter, and there are less requirements!
Except it's missing a lot of details. Method #1 manages to tell you
a lot of details about the requirements, in just a few lines.
In method #2 you need to open the script to see what it's doing.
Probably an easy task if it's a small 10-line script; harder if
it's one of these giant scripts that we were discussing in the previous
section.

Before shipping this new workflow to our users,
a good litmus test is to check how hard it is it to make changes
to the script and run it.
Can we still run the script locally, or is there something
that prevents us from doing so?

And this gets worse when we run the script in a remote environment,
for instance in CI or on Kubernetes!

Indeed, if our script *must* call Docker (or Compose), what
happens if we try to run that script in an environment that
is already containerized?
Sometimes we can use [Docker-in-Docker in CI], but it's not always
an option; so if our script relies on invoking Docker or Compose,
we're in trouble.

On the other hand, if we're sticking to "run `yadda-deploy.sh` in
an environment that has packages X, Y, and Z" it's way easier to do
because we already know which packages we need and which image has them.


## Using overly complex tools

After recommending that you use tools rather than shell scripts, here
is the opposite advice. Don't add a complex dependency if the problem
can be solved with a few lines of script (or with a tool that is
already used in the stack).

Example: let's say that we need to generate a file (configuration
or otherwise) from a template and environment variables.
In many cases, a [here document] is sufficient.

If the template has many `$`, rather than escaping them,
we could use `[envsubst]` from the `gettext` package.

If the variables come from a JSON file instead of the environment,
we might prepare them with a tool like `jq`.

If some variables need to be transformed, e.g. lowercase,
remove special characters, spaces, encode or decode base64,
compute hashes... We can install extra tools to do all these
transformations before calling `envsubst`.

Perhaps we also need to support loops?
At that point, we might decide to invest in a proper templating engine.
That's where things get really interesting!

If our stack includes a language like Node, Python, or Ruby,
there is a good chance that we can find a
small package that does what we need.
(For instance, in Python, the [Jinja2] package provides the `j2`
CLI tool.) On the other hand, if our stack doesn't include Python,
adding Python *just* so that we can install Jinja2 feels excessive.

If we are already using Terraform, it has a powerful templating
engine that can generate local or remote files. Great!
But adding Terraform *just* for its templating engine might
also be a tad much.

(To be honest, if I'm in a very minimal environment and I need
to generate fancy templates, I would probably write a script that
outputs the whole file that I need, and redirect the output
to the file to be generated. But each situation is different!)

We also need to be careful about using tools that are difficult
to learn, and/or that very few folks know how to use.
[Bazel] is probably one of the most
efficient ways to produce artifacts and run CI on huge codebases,
but how many of your colleagues are sufficiently familiar with
Bazel to maintain build rules? And when that one person leaves,
what will you do? 😬


## Conflicting names for scripts and images

Another memory from my early days in computer science: during
my first year using UNIX, I kept shooting myself in the foot
by calling my test scripts and programs `test`.

So what?

This is not a big problem in itself; but I was using DOS before.
On DOS, if you want to run a program named `HELLO.COM` or `HELLO.EXE`
located in your current directory, you can run `hello` directly;
you don't have to do `./hello` like on UNIX. So I had customized
my login scripts so that `.` was in my `$PATH`.

Maybe you see where this is going: instead of running `./test` I
was running `test` and ended up calling `/usr/bin/test` (also known as
`/usr/bin/[`) and wondering why nothing happened (because without arguments,
`/usr/bin/test` doesn't display anything and just exits).

My advice: avoid to name your scripts in a way that could conflict
with other popular programs. Some folks will see it and they will be careful,
others might not notice and accidentally run the wrong thing.

This is particularly true with 2-letter commands, because UNIX has so
many of them! For instance:
- bc and dc ("build container" and "deploy container" for some folks,
  but also some relatively common text-mode calculators on UNIX)
- cc ("create container" but also the standard C compiler on UNIX)
- go (conflicts with the Go toolchain)


## Building with Dockerfiles

Finally, sometimes, using a Dockerfile to build your image isn't the best
solution. In [Moving and Building Container Images, The Right Way],
Jason Hall explains in particular how to build and push images containing
Go programs efficiently and securely. Spoilers: it's specific to Go
(because Go has an outstanding toolchain), but even if you want to
containerize other languages, it's a good read, I promise.

Jason also mentions [Buildpacks]. I'm not a huge fan of Buildpacks;
perhaps because they remind me of my time at dotCloud, and that after
working for half a decade with similar build systems, it felt like
a huge relief to work with Dockerfiles. 🤷🏻 But they definitely have
merits so if you feel like Dockerfiles are too much (or, depending on
the perspective, not enough) you should definitely check Buildpacks.


## And more

As I said in the introduction of this series of tips:
don't treat these recommendations as absolute rules.
What I'm saying is “hey, careful, if you do this, it can have unexpected
consequences; look, here is what I suggest to improve the situation”.

When I deliver container training, I have a whole section about
tips & tricks to build “better images” and write “better Dockerfiles”.
I wrap it up with the following conclusion:

*The point of containers isn't to get smaller images.
The point of containers is to help us ship code
faster, more reliably, with less bugs, and/or at a bigger scale.
Let's say that you implement multi-stage builds,
and you realize that now your tests run slower or are breaking randomly.
Roll back, and try to address the main pain point instead!
If you spend half of the day waiting for your code to get
to staging or production because images take forever to push
and pull, then, yes, maybe it's a great idea to optimize image size.
But if it's not helping you to meet your goals, don't do it.*

Thanks for reading!

[Bazel]: https://bazel.build/
[Buildpacks]: https://buildpacks.io/
[distroless]: https://github.com/GoogleContainerTools/distroless
[Docker-in-Docker in CI]: http://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
[Ellen Körbes]: https://twitter.com/ellenkorbes
[envsubst]: https://skofgar.ch/dev/2020/08/how-to-quickly-replace-environment-variables-in-a-file/
[ephemeral containers]: https://kubernetes.io/docs/tasks/debug-application-cluster/debug-running-pod/#ephemeral-container
[foundation image pattern]: https://github.com/jpetazzo/foundation-example
[here document]: https://en.wikipedia.org/wiki/Here_document
[Ignore rules that make no sense]: https://twitter.com/PicardTips/status/1459900061366636552
[Jinja2]: https://pypi.org/project/Jinja2/
[live update]: https://docs.tilt.dev/tutorial/5-live-update.html
[Moving and Building Container Images, The Right Way]: https://articles.imjasonh.com/moving-and-building-images#what-to-do-instead-1
[Nixery]: https://nixery.dev/
[only a Sith deals in absolutes]: https://knowyourmeme.com/memes/only-a-sith-deals-in-absolutes
[part 1]: http://jpetazzo.github.io/2020/02/01/quest-minimal-docker-images-part-1/
[part 2]: http://jpetazzo.github.io/2020/03/01/quest-minimal-docker-images-part-2/
[part 3]: http://jpetazzo.github.io/2020/04/01/quest-minimal-docker-images-part-3/
[Quest for the Fastest Deployment Time]: https://www.youtube.com/watch?v=9C9BKzyZG_Y
