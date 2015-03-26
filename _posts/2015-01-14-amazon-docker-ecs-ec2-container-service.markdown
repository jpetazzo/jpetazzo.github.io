---
layout: post
title: My notes on Amazon's ECS (EC2 Container Service), aka Docker on AWS
---

This morning, I watched AWS' webinar presenting their container service.
Here are some quick notes, for those of you who are as curious as I was
about it!

This is not meant to be
[an](http://vimeo.com/111751807)
[intro](https://sysadmincasts.com/episodes/31-introduction-to-docker)
[to](https://www.youtube.com/watch?v=FdkNAjjO5yQ)
[Docker](https://www.docker.com/whatisdocker/).
This is not meant to be an
intro to EC2 or to AWS. This is for people who are already familiar with
AWS, specifically with EC2, and who are already familiar with Docker,
and wonder what's behind the ECS (EC2 Container Service) announcements
made at AWS re:invent last November.

AWS has made the [video] available if you want to watch the webinar
yourself.


## Bullet points

TL,DR:

- it's supposed to be a set of building blocks, usable "as-is" or as
  part of something more complex
- your containers will run on your EC2 instances (a bit like for Elastic
  Beanstalk, if you're familiar with that)
- there is no additional cost: you pay only for the EC2 resources
- it only works on VPC
- the service is currently in preview (behind a sign-up wall)
  in us-east-1; general availability will come in the next few months
- there is no console dashboard yet; you have to use the CLI or API
- for now, you can only start containers from public images hosted
  on the Docker Hub, but that's expected to change when the service
  goes out of preview

![I'm out of bullet points](/assets/bulletpoints.jpg)

## Glossary of terms

Here is some vocabulary to help you to mash through the [ECS docs].


### Container instance

A "container instance" can be any EC2 instance, running any distro
(Amazon Linux, Ubuntu, CoreOS...)

It just needs two extra software components:

- the Docker daemon,
- the AWS ECS agent.

The ECS agent is open source (Apache license). You can check the
[ECS agent repo on github].


### Cluster

That's a pool of resources (i.e. of container instances).

A cluster starts being empty, and you can dynamically scale it up and
down by adding and removing instances.

You can have mixed types of instances in here.

It's a regional object, that can span multiple AZs.


### Task definition

It's an app definition in JSON. The format is conceptually similar
to [Fig], but not exactly quite like it.

I don't know why they didn't pick something more like Fig, or more
like the [Docker Compose] project. It might be because almost everything
else on AWS is in JSON, and they wanted to stick to that.

Note: [Micah Hausler](https://twitter.com/micahhausler) wrote
[container-transform](https://github.com/ambitioninc/container-transform),
a tool to convert Fig/Compose YAML files to the ECS task format:

<blockquote class="twitter-tweet" data-conversation="none" lang="en"><p><a href="https://twitter.com/jpetazzo">@jpetazzo</a> <a href="https://twitter.com/docker">@docker</a> I wrote a little fig.yml &lt;==&gt; ecs-task.json converter. <a href="https://t.co/brcOtFvLAk">https://t.co/brcOtFvLAk</a></p>&mdash; Micah Hausler (@micahhausler) <a href="https://twitter.com/micahhausler/status/555734176495042560">January 15, 2015</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>


### Task

A task is an instanciation of a task definition. In other words, that will
be a group of related, running containers.


## The workflow

So, how does one use that? The workflow looks like this:

0. Build image using whatever you want.
1. Push image to registry.
2. Create JSON file describing your *task definition*.
3. Register this *task definition* with ECS.
4. Make sure that your *cluster* has enough resources.
5. Start a new *task* from the *task definition*.

Now, diving into the details; there are 3 ways to start a *task*:

1. Use the CLI command `start-task`. You must then specify the *cluster*
   to use, the *task definition*, and the exact *container instance* on
   which to start it. It's a bit like doing manual scheduling.
2. Use the CLI command `run-task`. You must then specify the *cluster*,
   *task definition*, and an instance count. It will run ECS default
   resource scheduler (which is a random scheduler).
3. Bring your own scheduler!

The webinar had a demo involving Mesos; they started container from
Marathon, from Chronos, and using the CLI as well, and the containers
were visible everywhere. That looked cool. Initially, I didn't
understand how it worked; but the people who built it were kind enough
to chime in and explain:

<blockquote class="twitter-tweet" data-conversation="none" lang="en"><p><a href="https://twitter.com/jpetazzo">@jpetazzo</a> the Mesos integration is via a Mesos scheduler driver</p>&mdash; Deepak Singh (@mndoci) <a href="https://twitter.com/mndoci/status/555554709650436097">January 15, 2015</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet" data-conversation="none" lang="en"><p><a href="https://twitter.com/mndoci">@mndoci</a> <a href="https://twitter.com/jpetazzo">@jpetazzo</a> the scheduler drive speaks to AWS ECS only, there are no Mesos masters or slaves involved.  Just ECS + Marathon/Chronos</p>&mdash; William Thurston (@williamthurston) <a href="https://twitter.com/williamthurston/status/555631721769488384">January 15, 2015</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>


## Networking

Not much on that side.

Containers can be linked (the *task definition* allows to name
containers, and then to indicate that a container is linked to
another one) but I don't know how that works.


## My personal take

My understanding is, that ECS as it is today is a technological preview.

There are a some items that are still to be clarified, like the use
of private registries (but on that front, [Docker Hub Enterprise] might
eventually come on AWS; and it will likely integrate nicely with ECS).


### Docker-centric point of view

I would love if:

- *container instances* and *clusters* could be managed with
  [Docker Machine]
- *task definitions* and *tasks* could be managed with [Docker Compose]
  as the frontend
- [Docker Swarm] could be used as a custom scheduler

Those interoperability points would let anyone move their container
workloads seamlessly form/to ECS. More importantly, they will let
anyone use the elasticity and scale of EC2, without having to learn
APIs and concepts specific to ECS.


### AWS-centric point of view

I would love if:

- ECS could integrate with Cloud Formation (that's plannned)
- I could also build images (that's pretty trivial with an
  ad-hoc instance)...
- ... and push them on a S3-backed registry that would be
  neatly integrated with ECS (notably for security credentials)


## Last words

Full disclaimer: I haven't tested ECS yet (and unfortunately,
I don't know if I'll be able to). So if you have any feedback
or useful tip that would be useful for others, don't hesitate
to let me know!


[ECS docs]: http://aws.amazon.com/documentation/ecs/
[ECS agent repo on github]: http://aws.amazon.com/documentation/ecs/
[Fig]: http://www.fig.sh
[Docker Compose]: http://blog.docker.com/tag/docker-compose/
[Docker Machine]: https://github.com/docker/machine
[Docker Swarm]: https://github.com/docker/swarm
[Docker Hub Enterprise]: http://blog.docker.com/2014/12/docker-announces-docker-hub-enterprise/
[video]: https://connect.awswebcasts.com/p59n405xep5/
