---
layout: post
title: Efficient management Python projects dependencies with Docker
tags: docker
---

There are many ways to handle Python app dependencies with Docker. Here is
an overview of the most common ones -- with a twist.

In our examples, we will make the following assumptions:

- you want to write a Dockerfile for a Python app;
- the code is directly at the top of the repo (i.e. there's a `setup.py`
  file at the root of the repo);
- your app requires Flask (and possibly other dependencies).


## Using your distro's packages

This is the easiest method, but it has some pretty strict requirements.

1. The Python dependencies that you need must be packaged by your distro.
   (Obviously!)
2. Almost as obvious, but a bit more tricky: your distro has to carry
   the *specific version* that you need. You want Django 1.6 but your
   distro only have 1.5? Too bad!
3. You must be able to map the Python package name to the distro package
   name. Again, that sounds really obvious, and it's not a big deal
   if you are familiar with your distro. For instance, on Debian/Ubuntu,
   in most cases, Python package `xxx` will be packaged as `python-xxx`.
   But if you have to deal with a complex Python app with a large-ish
   `requirements.txt` file, things might be more tedious.
4. If you run multiple apps in the same environment, their requirements
   must not conflict with each other. For instance, if you install
   (on the same machine) a CMS system and a ticket tracking system
   both depending on different versions of Django, you're in trouble.

The most common answer to those constraints is "just use virtualenv
instead!", and this is the generally accepted strategy. However, before
ditching distro packages, let's remember two key things!

1. If we're using Docker, most of those problems go away (just like
   when using virtualenv), because you can use different containers
   for different apps (and get rid of version conflicts). Also,
   if you need a more recent (or older) version of a package, you
   can use a more recenet (or older) version of the distro, and a
   moderate amount of luck will make sure that you can find the
   right thing. Just check e.g. http://packages.debian.org/ or
   http://packages.ubuntu.com/ to check version numbers first.
2. Sometimes, it happens that a specific Python dependency will
   be incompatible with your Python version, or some other library
   on your system. Example: I recently stumbled upon a version
   of simplejson which didn't work with Python 3.2. This is less
   likely to occur with distro packages, because such problems
   will be caught by the packagers and the other users. Free QA!

So what does your Dockerfile look like?

```
# Use a specific version of Debian (because it has the exact Python for us)
FROM stackbrew/debian:jessie
RUN apt-get install -qy python3
RUN apt-get install -qy python3-flask
ADD . /myapp
WORKDIR /myapp
RUN python3 setup.py install
EXPOSE 8000
CMD myapp --port 8000
```

Pretty simple -- especially if you don't have too many requirements.
Note how we `apt-get install` each package with a separate command.
It creates more Docker layers, but that's OK, and it means that if
you add more dependencies later, the cache will be used. If you use
a single line, each time you add a new package, everything will be
downloaded and installed again.


## requirements.txt

If you can't use the packages of your distro (they don't have that
specific version that you absolutely need!), or if you are using
some stuff which is just not packaged at all, here's our "plan B".
In that situation, you will generally have a `requirements.txt`
file, describing the dependencies of the app, pinned to specific
versions. That kind of file can be generated with `pip freeze`,
and those dependencies can then be installed with `pip install
-r requoirements.txt`.

That's also the preferred solution when you want to use some
dependencies straight from GitHub, BitBucket, or any other code
repository, because pip supports that too.

Let's see first what the Dockerfile will look like, and discuss
the pros and cons of this approach.

```
FROM stackbrew/debian:jessie
RUN apt-get install -qy python3
RUN apt-get install -qy python3-pip
ADD . /myapp
WORKDIR /myapp
RUN pip-3.3 install -r requirements.txt
RUN pip-3.3 install .
EXPOSE 8000
CMD myapp --port 8000
```

While it looks similar to what we did earlier, there is actually
a huge difference (apart from the fact that dependencies are
no longer handled by Debian, but directly by pip). Dependencies
are now installed *after* the `ADD` command. This is a big deal
because as of Docker 0.7.1, the `ADD` command is not cached,
which means that all subsequent commands are not cached, neither.
So each time you build this Dockerfile, you end up re-installing
all the dependencies, which could take some time.

This is a significant drawback, because development is now
significantly slower, since each build can take minutes instead
of seconds.

So how do we solve that problem? Well, let's see!


## Two Dockerfiles

A common workaround to `ADD` issue is to use *two* Dockerfiles.
The first one installs your dependencies, the second one installs
your code. They will look like this:

```
FROM stackbrew/debian:jessie
RUN apt-get install -qy python3
RUN apt-get install -qy python3-pip
ADD requirements.txt /
RUN pip-3.3 install -r requirements.txt
```

This first Dockerfile should be built with a specific name; e.g.
`docker build -t myapp .`. Then, the second Dockerfile reuses it:

```
FROM myapp
ADD . /myapp
WORKDIR /myapp
RUN pip-3.3 install .
EXPOSE 8000
CMD myapp --port 8000
```

Now, code modifications won't cause all dependencies to be re-installed.
However, if you change dependencies, you have to manually rebuild the
first image, then the second.

This workaround is good, but has two drawbacks.

1. You have to remember to rebuild the first image when you update
   dependencies. That sounds obvious and easy, but what happens if
   someone else updates `requirements.txt`, and then you pull their
   changes from git? Are you sure that you will notice the change?
   Maybe you should setup a git hook to remind you?
2. Workflows like [Trusted Builds] get more complicated as well.
   It's still possible to get full automation, though. You can
   put the first Dockerfile (and the requirements file) in a
   subdirectory of the repository, and create a first Trusted
   Build for e.g. `username/myappbase`, pointing at that subdirectory.
   Then create a second Trusted Build, e.g. `username/myapp`, pointing
   at the root directory, and using `FROM username/myappbase`.

I appreciate the convenience of being able to use two Dockerfiles,
but at the same time, I believe that it makes the build process
more complicated and error-prone.

So let's see what else we could do!


## One-by-one pip install

We are in a kind of catch 22: we want to `pip install -r requirements.txt`,
but if we `ADD requirements.txt` we break caching, And we want caching.

What would McGyver do?

Instead of installing from requirements.txt, let's install each package
manually, with pip, with different `RUN` commands. That way, those
commands can be properly cached. See the following Dockerfile:

```
FROM stackbrew/debian:jessie
RUN apt-get install -qy python3
RUN apt-get install -qy python3-pip
RUN pip-3.3 install Flask
RUN pip-3.3 install some-other-dependency
ADD . /myapp
WORKDIR /myapp
RUN pip-3.3 install .
EXPOSE 8000
CMD myapp --port 8000
```

Now we won't reinstall dependencies each time we rebuild. Great.
However, our dependencies are now duplicated in two places: in
`requirements.txt`, and in `Dockerfile`. It's not the end of the
world, but if you update one of them without the other, confusion
will ensue.

So this solution is nice from a build time and tooling perspective,
but it doesn't abide by "DRY" principles (Don't Repeat Yourself),
which is another way to say that it can be subtly error-prone as well.


## Combo

I'm therefore suggesting to mix two of the previous solutions to
solve the issue! Really, the idea is to install dependencies *twice*.
Or rather, to install them the first time with `RUN` statements (which
get cached), and execute `pip install -r requirements.txt` after the `ADD`.
The latter won't get cached, but pip is nice, and it won't reinstall
things that are already installed.

That way, you leverage the caching system of the Docker builder,
but at the same time, if you update `requirements.txt` without updating
`Dockerfile`, the `pip install` command will patch up your image
anyway, by upgrading your dependencies to the right version. The build
will just be slower until you update the Dockerfile, but that's it.

The Dockerfile will look like this:

```
FROM stackbrew/debian:jessie
RUN apt-get install -qy python3
RUN apt-get install -qy python3-pip
RUN pip-3.3 install Flask
RUN pip-3.3 install some-other-dependency
ADD . /myapp
WORKDIR /myapp
RUN pip-3.3 install -r requirements.txt
RUN pip-3.3 install .
EXPOSE 8000
CMD myapp --port 8000
```


## Virtualenv

If you followed carefully, you noticed that we mentioned virtualenv
in the beginning of this post, but we haven't used it so far. Is 
virtualenv useful with Docker? *It depends!*

On a regular machine (be it your local development machine or a
deployment server), you will have multiple Python apps. If they rely
only on Python dependencies that happen to be packaged by your distro,
great. Otherwise, virtualenv will come to the rescue; either as a
sidekick to your distro's packages (by complementing them) or as a
total replacement (if you create the virtualenv with `--no-site-packages`).

With Docker, you will generally deploy one single app per container;
so why use virtualenv? It might still be useful to advert conflicts
between Python libs installed as distro packages, and libs installed
with pip. This is not very likely for simple projects, but if you
have a bigger codebase with many dependencies, *and* also install
distro packages bringing their own Python dependencies with them,
it could happen.


## Other points of view

There is no right or wrong solution for that matter. Depending on
the size of your project, on the number of dependencies, and how
their interact with your distro, one method can be better than
another.

On that topic, I suggest that you read [Nick Stinemates]' blog
post about running [Python apps with Docker], or [Paul Tagliamonte]
blog post about the respective merits of [apt and pip].


[apt and pip]: http://notes.pault.ag/debian-python/
[Nick Stinemates]: https://twitter.com/nickstinemates
[Paul Tagliamonte]: https://twitter.com/paultag
[Python apps with Docker]: http://stinemat.es/ive-been-using-docker-inefficiently/
[Trusted Builds]: http://blog.docker.io/2013/11/introducing-trusted-builds/

