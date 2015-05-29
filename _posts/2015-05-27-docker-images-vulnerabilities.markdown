---
layout: post
title: Someone said that 30% of the images on the Docker Registry contain vulnerabilities
---

This number is wonderful. Not because it's high or low, but because it
exists. The fact that it is possible (and relatively easy) to compute this
metric means that it will be possible (and relatively easy) to improve it,
among other things.

Disclaimer: I work for Docker, and while this post is not sponsored or
approved by my employer, you are obviously welcome to take it with a
grain of salt.

The original number was published on [BanyanOps Blog]. 


## Counting vulnerabilities

First, let's see how we can come up with those metrics. The process is
rather simple:

- get a list of images on the Docker registry;
- download those images;
- audit them for vulnerabilities.

That looks almost too simple, so let's dive a little bit into the details.


### Listing images

Listing **official images** is easy. They are all built using an
automated system called [bashbrew], using publicly available recipes.
By the way, this means that if you want to rebuild the official
images yourself, it is very easy to do so. (Keep in mind that some
of those recipes include blobs and tarballs used for bootstrapping
purposes; so sometimes you will have to go one step further to
rebuild those blobs and tarballs.)

The recipes for all official images are available in the [docker-library]
on GitHub.

Listing other images (the ones belonging to users and organizations)
is harder. The hub doesn't provide a way to list them all right now,
so an acceptable workaround is to [search] for a very common word,
e.g. `a`, and go from there. Of course, this requires some crawling;
and you might end up missing a few users, but that will get you
pretty close. (That being said, I'm told that the new registry API
has [something nice] to make that task easier...)


### Downloading the images

Downloading the images is trivial. If you want to do it without much
fuss, just run a Docker daemon, and run `docker pull username/imagename:tag`.

If you want to get a tarball of the container filesystem, that's easy:
just run `docker export username/imagename:tag`. (Redirect your standard
output somewhere, otherwise you terminal will be a sad panda.)

If you don't trust the Docker daemon, you can also check the registry API
([v1], [v2])
and download the layers through the API, then reconstruct the image from
those layers. I'll spare you the details, but as of today, layers are
regular tarballs, and you can just unpack them in top of each other
(in the right order) to reconstruct an image. Nothing fancy is involved;
the only "trick" is to watch for whiteouts. Whiteouts are special
marker files indicating that "a file used to be there, but it is no more."
In other words, if a layer has the file `/etc/foo.conf` but was removed
in an upper layer, then that upper layer will have `/etc/.wh.foo.conf`,
and the file `foo.conf` won't show up in the container. It is masked
by the whiteout, so to speak.

As it turns out, the amazing [Tianon] actually wrote a [script] to do
exactly that, if you're interested!


### Auditing the images

There are a few different things you can do at this stage. The details are
way beyond the scope of this post; but here are some of the things that
you might want to do in a comprehensive security audit:

- execute `yum-security` or equivalent, to make sure that no security
  upgrade is available at this point;
- better: get list and version of all installed packages, and check that no
  vulnerable version is present;
- compute hash of each file on the system, and compare them against a
  set of hashes of known vulnerable files;
- execute automated tools (like `chkrootkit`) to find
  suspicious files;
- execute a number of vulnerability tests, tailored for specific 
  vulnerabilities. The goal of those tests is to try to exploit a
  vulnerability, and tell you "your system is vulnarable because
  I managed to exploit this vulnerability" or "I failed to exploit
  this vulnerability, so your system is probably not vulnerable."

Things get particularly interesting in the context of containers, because
it becomes easy (and convenient) to automate all those things with
Docker. For instance, you can put your vulnerability analysis toolkit 
in `/tmp/toolkit`, then for each image `$I`, execute something like
`docker run -v /tmp/toolkit:/toolkit $I /toolkit/runall.sh`.

(Note: this assumes that your toolkit is statically linked and/or
self-contained, i.e. doesn't rely on anything in your container image
that might fool the toolkit itself. My main point here is to show
that if you need to hammer your container image with a bunch of
tests, you can do that *in containers* to make your life easier,
and the overall process will be much faster than it would usually be
if you had to make a full copy of the audited machine for each test.)


## Improving the metric

Alright, so we run all those tests, and we find that an outrageously
high number of images contain vulnerable packages. How can we change that?

For official images, the easiest path is to follow Docker's [security]
guidelines. Down the road, as the number of official images increases,
Docker will improve this mechanism to automatically notify upstream
security lists for official images.

For non-official images, you can check the `Author` field in an image:

```
$ docker inspect --format '{{ "{{" }}.Author}}' bin/ngrep
Jerome Petazzoni <jerome@docker.com>
```

If the image comes from an automated build, you can look up its
source repository, and contact them directly.

If you are directly impacted by the vulnerability, and want things
to move faster, you can rebuild the image yourself, and/or investigate
to see what's needed to patch the vulnerability, and submit a pull
request with the appropriate changes. The intent here is not to offload
security to the end users, but rather to empower them to contribute to
security if they are willing and able to do so.

Down the road, you can expect all those steps to be improved and
streamlined. Automation will be built to reduce the friction
around contacting the appropriate authority, and minimize the time
required to release patched version.


### But 30% is a lot, right?

It might sound like 30% of "vulnerable images" is a lot. That's also
what I thought first. But if you take a closer look, a large fraction
of those images are older images, that are deliberately not updated.

*What? Deliberately not updated?*

Yes, and there are a couple of good reasons for that. The first one
is (for some of them) **parity** with other media. Some distributions
want version `XYZ` to be consistent across CD/DVD media, network installs, 
VM images, and containers. The second reason (which also explains
the first reason) is **repeatable builds**.

Imagine that you have a problem with some servers running Ubuntu 12.04,
but you can't reproduce the issue with a new install of Ubuntu 12.04
(let alone 14.04). After investigating further, it turns out that
the problem only appears on machines installed at a given time, with
Ubuntu 12.04.2. If a container image is available for 12.04.2, you will
be able to reproduce the bug; otherwise, you will have to fetch it from
elsewhere somehow. That's why the Docker Hub has images for some older
versions in the exact state that they were when they were released -
including security issues. That being said, we have put pretty big yellow 
police tape everywhere saying "LEGACY IMAGES - DO NOT CROSS," so we hoped
that it would be obvious that those images should *not* be included
in a security metric...

Let's hope that people will realize that next time they compute
metrics on the Docker Hub.


## Taking action - locally

*We might be running vulnerable images! Halp! What do, what do?*

There again, the situation isn't as bad as it looks. When you (or anybody
else) do your audit of those images (official, public, or private), the
outcome is a list of images (as unique hashes) alongside with a "PASS"
or "FAIL" status. (In the case of "FAIL" you hopefully have some details,
e.g. "Seems to be vulnerable to ShellShock / CVE-2014-7187 and others)"
or "Has package OpenSSL 1.0.1c / CVE-2014-0160.)


### Webscale security audit

You can take this list, and compare it to the images you have locally.
That's where things get really interesting. By doing a simple (and cheap)
match of your local images with this list, you will know instantly
if you are running vulnerable images. That scales nicely to thousands
or millions of hosts.

It also means that things can be decoupled nicely: your security
auditor doesn't need access to your production systems (or even
to your development ones). They don't even need to know *what*
you are running: they perform an analysis on a broad range of
images, and you consume the result. You can also have multiple
security companies and compare their results.


### What if my containers have been modified after creation?

For starters, you shouldn't do that. If you need to upgrade
something in a container, you should make a new image and run
that image. OK, but what if you've done it anyway?

Then all bets are off, *but* at least we can find out that it's
happening. As part of the security audit, you can run `docker diff`
on your running containers to find out if they have been modified.
(Normally, the output of `docker diff` should be empty. Note that
if you have started a container with a shell, or dropped into
a container with `docker exec`, you might see a few modifications
though. But production containers should not show any change.)

Protip: you can even *prevent* modifications, by running your
containers with the `--read-only` flag. This will make the
container filesystem read-only, warranting that `docker diff`
will remain empty.

To inspect all your containers with a single command, you can do:

```
docker ps -q | xargs -I {} docker diff {}
```

(Courtesy of [@diogomonica]!)


### What if I have built custom containers?

If you have built your own containers, I suggest that you
push them to a repository. If it's the public one, we're back
to the initial scenario. If it's a private repository... Let's
check the next section!


## What about private images and registries?

What if you are pushing private images? What if you are pushing
on a local registry, or on Docker Hub Enterprise?

Things obviously get more complex. You can't expect someone
to magically tell you "image ABC is vulnerable to CVE-XYZ"
if they never saw image ABC.

Here are a few things that can happen:

- security providers can offer image scanners, that you can
  run on your images;
- security providers can go farther, and integrate with the Docker
  registry. This can be done either by delegating read access
  (for private images on the Docker Hub) or even by on-prem
  deployment of the security scanner (in the case of Docker Hub
  Enterprise). In both cases, that gives the ability to automatically
  scan an image right after it's pushed, and immediately report
  any vulnerability.


## Conclusions

There are two things that I would like to emphasize, because I
believe that they will yield to positive results in the security
field.

1. Having numbers is *good*. Once we have metrics, we can improve them.
   Docker takes security seriously, and you can be sure that we'll work
   with the community and image maintainers to improve those metrics.
2. Having an ecosystem and community like those around Docker and the
   Docker Hub make them amazing places to standardize.
   As Solomon pointed out in a few keynotes, one of the most important things
   in Docker is not the technology, but to *get people to agree on something.*

The last point means that Docker now has enough critical mass to justify
the development of transverse tools (including security audit) that will
benefit the whole ecosystem. The outcome will be an improved security -
for everybody.


### Docker cares about security

If you get the impression that Docker Inc. doesn't care about security,
you're far from the truth. As pointed out above, we have a responsible
disclosure [security] policy, and we have always been very fast to
address issues that we were aware of. No software is exempt from
bugs. Docker is written by humans, and even if some of them are amazing,
they still make mistakes. What matters is how seriously we take security
reports and how fast we address them; and I think we've been doing well
on that side.

If you want to make your Docker install more secure, I recommend that
you also check [dockerbench]. As I write those lines, it contains an
automated assessment tool, evaluating a Docker host using the criterias
of the [CIS Docker 1.6 Benchmark]. It checks a large number of things
(e.g., that SELinux or AppArmor are enabled) and produces a report.

This is the first of many tools that Docker will produce or contribute
to, to help you to run Docker safely without holding a Ph.D in container
security or hiring [Taylor Swift].

Also, we encourage public discussion, and security concerns are no
exception!  There is an interesting [thread] on the Docker Library 
repository about this topic. 


### Extra notes

I've been asked to clarify why containers are useful at all, if we don't
triple-check the provenance of all the things we run. Here are a few examples.

- Containers allow us to test risky things
  (like the infamous `curl ... | sh`)
  in a sandbox to see exactly what they're doing, thanks to `docker diff`.
- Containers allow us to test risky things
  (like a commercial vendor's `install.sh`)
  in a sandbox to see exactly what they're doing, thanks to `docker diff`.
- Containers allow us to test risky things
  (like installing a npm, pip, gem... package of unknown origin)
  in a sandbox to see exactly what they're doing, thanks to `docker diff`.
- Containers allow us to test risky things
  (like installing a deb, rpm, or other distribution package)
  in a sandbox to see exactly what they're doing, thanks to `docker diff`.
- Containers allow us to test risky things
  (like installing a [dangerous squid package])
  in a sandbox to see exactly what they're doing, thanks to `docker diff`.

I guess you see the pattern here. Just because things come in a familiar
form doesn't mean that they are safe. But we can use Docker to improve
security. 


[BanyanOps Blog]: http://www.banyanops.com/blog/analyzing-docker-hub/
[bashbrew]: https://github.com/docker-library/official-images#bashbrew
[CIS Docker 1.6 Benchmark]: https://benchmarks.cisecurity.org/downloads/show-single/?file=docker16.100
[dangerous squid package]: https://bugzilla.redhat.com/show_bug.cgi?id=1202858
[@diogomonica]: https://twitter.com/diogomonica
[dockerbench]: http://dockerbench.com/
[docker-library]: https://github.com/docker-library/official-images/tree/master/library
[script]: https://github.com/docker/docker/blob/master/contrib/download-frozen-image.sh
[search]: https://registry.hub.docker.com/search?q=a&t=User
[security]: https://www.docker.com/resources/security/
[something nice]: https://registry.hub.docker.com/v2/repositories/
[Taylor Swift]: https://twitter.com/swiftonsecurity
[Tianon]: https://twitter.com/tianon
[thread]: https://github.com/docker-library/official-images/issues/763
[v1]: https://docs.docker.com/reference/api/registry_api/
[v2]: https://github.com/docker/distribution/blob/master/docs/spec/api.md
