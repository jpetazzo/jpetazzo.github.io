---
layout: post
title: Putting data in a volume in a Dockerfile
---

In a Dockerfile, if you put data in a directory, and then
declare that directory to be a volume, weird things can happen.
Let's see what exactly.


## The problem

Someone contacted me to ask about very slow build times. They
told me: "This is weird. In this Dockerfile, the `VOLUME` and
`CMD` lines take a few minutes. Why is that?"


## The diagnostic

I was very intrigued, and investigated. And I found the reason!

The Dockerfile looked roughly like this:

```
FROM someimage
RUN mkdir /data
ADD http://.../somefile1 /data/somefile1
ADD http://.../somefile2 /data/somefile2
ADD http://.../somefile3 /data/somefile3
ADD http://.../somefile4 /data/somefile4
VOLUME /data
CMD somebinary
```

The files added were very big (more than 10 GB total).

The `ADD` steps do exactly what you think they do: they download
the files, and place them in `/data`.

Then, two particular things happen.

First, when you get to `VOLUME /data`, you inform Docker that you want
`/data` to be a volume. If Docker doesn't do anything special, when
you create a container from that image, `/data` will be an empty volume.
So instead, when you create a container, Docker makes `/data` to be
a volume (so far, so good!) and then, it copies all the files from
`/data` (in the image) to this new volume. If those files are big,
then the copy will take some time, of course.

This copy operation will happen *each time a container is created
from the image*.

The second thing might also surprise you: even though `VOLUME` and
`CMD` just modify some metadata, they still create a new container
from the image, *then* modify that metadata, and finally create
the image from the modified container.

It means that a new "anonymous" volume will be created for `/data`,
and its content will be populated from the image - for *each*
step of the Dockerfile, even when it's not strictly necessary.


## The solution

So, what do?

Don't put a lot of data in a volume directory. That's pretty much it!

It's OK to have a few megabytes of data in a volume directory.
For instance, a blank (or almost empty) database containing a
small data set. But, if it's bigger than that, you probably
want to do differently.

How exactly?

The easiest way is to *not* use a volume. Just put the data in a 
normal directory, and it will be part of the copy-on-write filesystem.
This is the right thing to do if the data will be read-only, or
if it will have only very little modifications during the lifetime
of the container.

A few examples:

- a GeoIP database (mapping IP addresses to geographic information);
- pre-generated tiles for a map server;
- data and possibly (slow-to-update) search indexes for a significant
  corpus, like e.g. offline copies of Wikipedia;
- etc.

Now what if you really want the data to be on a volume, because
you need native I/O speeds?

Then, of course, use a volume. But you should decouple the application
and its data. Author a first container image for the application itself,
without any significant amount of data (or maybe a minimal test set,
allowing to test that the image works properly). It is OK to put the
data on a volume. Since it is small, it won't cause a significant
performance degradation when you work with this container.

Then, author a second container image, just for this data.
If you need the application to generate the data, you can base this
second container image on the first one. In this image, you *can*
put the data on a volume, but you don't have to. It is probably
better to *not* declare the data directory as a volume, to avoid
the bad surprise of "oops, I've triggered a 10 GB data copy again!"
each time you start this container.

Once you have your two container images ready, create a container from
the second one. If the data directory is not a volume, it is time
to declare it explicitly now, with the `-v` option. This container
will be a "data container"; it will not run the service. (When creating
it, you could override the process with `--entrypoint true`, for instance.)

Last but not least, start the actual service container, based on
the first image, using the data container volumes with the `--volumes-from`
option.

Voilà!


## Additional readings

Check this out:

- [Official documentation on data volumes](
  https://docs.docker.com/userguide/dockervolumes/)
- [Another explanation of data volumes](
  https://medium.com/@ramangupta/why-docker-data-containers-are-good-589b3c6c749e)
- [And yet another](
  http://www.tech-d.net/2013/12/16/persistent-volumes-with-docker-container-as-volume-pattern/)
- [My classic piece on containers, SSH, and how to use volumes for fun and profit](
  http://jpetazzo.github.io/2014/06/23/docker-ssh-considered-evil/)
