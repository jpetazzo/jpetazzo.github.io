---
layout: post
title: "Using Compose to go from Docker to Kubernetes (1/2)"
---

For anyone using containers, Docker is a wonderful
development platform, and Kubernetes is an equally
wonderful production platform. But how do we go
from one to the other? Specifically, if we use
Compose to describe our development environment,
how do we transform our Compose files into Kubernetes
resources?

*This is a translation of an article initially
published in French. So feel free to read the
[French version](/2018/11/07/docker-compose-kubernetes-1/)
if you prefer!*

Before we dive in, I'd like to offer a bit of
advertising space to the primary sponsor of this blog,
i.e. myself: ☺

{% include ad_en_short.markdown %}


## What are we trying to solve?


When getting started with containers, I usually suggest
to follow this plan:

- write a Dockerfile for one service, part of one application,
  so that this service can run in a container;
- run the other services of that app in containers as well,
  by writing more Dockerfiles or using pre-built images;
- write a Compose file for the entire app;
- ... stop.

When you reach this stage, you're already leveraging
containers and benefiting from the work you've done so far,
because at this point, anyone (with Docker installed on
their machine) can build and run the app with just three
commands:

```bash
git clone ...
cd ...
docker-compose up
```

Then, we can add a bunch of extra stuff: continuous
integration (CI), continuous deployment (CD) to pre-production ...

And then, one day, we want to go to production with these
containers. And, within many organizations, "production with
containers" means Kubernetes. Sure, we could debate about
the respective merits of Mesos, Nomad, Swarm, etc., but here,
I want to pretend that we chose Kubernetes (or that someone
chose it for us), for better or for worse.

So here we are! How do we get from our Compose files to
Kubernetes resources?

At first, it looks like this should be easy: Compose is using
YAML files, and so is Kubernetes.

![I see lots of YAML](https://pbs.twimg.com/media/Dfwl3oSW4AING2Z.jpg)

*Original image by [Jake Likes Onions](
http://jakelikesonions.com/post/158707858999/the-future-more-of-the-present
), remixed by [@bibryam](https://twitter.com/bibryam/status/1007724498731372545).*

There is just one thing: the YAML files used by Compose
and the ones used by Kubernetes have nothing in common
(except being both YAML). Even worse: some concepts
have totally different meanings! For instance, when using
Docker Compose, a [service](
https://docs.docker.com/get-started/part3/#about-services)
is a set of identical containers (sometimes placed behind
a load balancer), while when using Kubernetes, a [service](
https://kubernetes.io/docs/concepts/services-networking/service/)
is a way to access a bunch of ressources (for instance,
containers) that don't have a stable network address.
When there are multiple resources behind a single service,
that service then acts as a load balancer. Yes, these
different definitions are confusing; yes, I wish the authors
of Compose and Kubernetes had been able to agree on a common
lingo; but meanwhile, we have to deal with it.

Since we can't wave a magic wand to translate our YAML
files, what should we do?

I'm going to describe three methods, each with its own
pros and cons.


## 100% Docker

If we're using a recent version of Docker Desktop
(Docker Windows or Docker Mac), we can deploy a Compose
file on Kubernetes with the following method:

1. In Docker Desktop's preferences panel, select
   "Kubernetes" as our orchestrator. (If it was set
   to "Swarm" before, this might take a minute or two
   so that the Kubernetes components can start.)
2. Deploy our app  with the following command:
   ```bash
   docker stack deploy --compose-file docker-compose.yaml myniceapp
   ```

That's all, folks!

In simple scenarios, this will work out of the box:
Docker translates the Compose file into Kubernetes
resources (Deployment, Service, etc.) and we won't have
to maintain extra files.

But there is a catch: this will run the app on the
Kubernetes cluster running within Docker Destkop on
our machine. How can we change that, so that the
app runs on a production Kubernetes cluster?

If we're using Docker Enterprise Edition, there is
an easy solution: UCP (Universal Control Plane) can do
the same thing, but while targeting a Docker EE cluster.
As a reminder, Docker EE can run on the same cluster,
side-by-side, applications managed by Kubernetes, and
applications managed by Swarm. When we deploy an app
by providing a Compose file, we pick which orchestrator
we want to use, and that's it.

(The [UCP documentation](https://docs.docker.com/ee/ucp/kubernetes/deploy-with-compose/)
explains this more in depth. We can also read
[this article on the Docker blog](
https://blog.docker.com/2018/05/kubecon-docker-compose-and-kubernetes-with-docker-for-desktop/
).)

This method is fantastic if we are already using Docker
Enterprise Edition, or if we plan to do so ; because
in addition to being the simplest option, it's also the
most robust, since we'll benefit from Docker Inc's support
if needed.

Alright, but for the rest of us who *do not* use Docker EE,
what do?


## Use some tools

There are a few tools out there to translate a Compose file
into Kubernetes resources. Let's spend some time on
[Kompose](http://kompose.io/), because it's (in my humble
opinion) the most complete at the moment, and the one with
the best documentation.

We can use Kompose in two different ways: by working
directly with our Compose files, or by translating them
into Kubernetes YAML files. In the latter case, we deploy
these files with `kubectl`, the Kubernetes CLI. (Technically,
we don't have to use the CLI; we could use these YAML files
with other tools like [WeaveWorks Flux](https://github.com/weaveworks/flux)
or [Gitkube](https://gitkube.sh/), but let's keep this simple!)

If we opt to work directly with our Compose files, all we
have to do is use `kompose` instead of `docker-compose` for
most commands. In practice, we'll start our app with
`kompose up` (instead of `docker-compose up`), for instance.

This method is particularly suitable if we are working
with a large number of apps, for which we already have
a bunch of Compose files, and we don't want to maintain
a second set of files. It's also suitable if our Compose
files evolve quickly, and we want to avoid divergences
between our Compose files and our Kubernetes files.

However, sometimes, the translation produced by Kompose
will be imperfect, or even outright broken. For instance,
if we are using local volumes
(`docker run -v /path/to/data:/data ...`),
we need to find another way to bring these files inside
our containers once they run on Kubernetes. (For instance,
by using [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).)
Sometimes, we might want to adapt the application
architecture: for instance, to ensure that the web server
and the app server are running together, within the same pod,
instead of being two distinct entities.

In that case, we can use `kompose convert`, which will
generate the YAML files corresponding to the resources that
would have been created with `kompose up`. Then, we can edit
these files and touch them up at will before loading them
into our cluster.

This method gives us a lot of flexibility (since we can
edit and transform the YAML files as much as necessary before
using them), but this means any change or edit
might have to be done again when we update the original Compose
file.

If we maintain many applications, but with similar architectures
(perhaps they use the same languages, frameworks, and patterns),
then we can use `kompose convert`, followed by an automated
post-processing step on the generated YAML files. However,
if we maintain a small number of apps (and/or they are very
different from each other), writing custom post-processing
scripts suited to every scenario may be a lot of work. And
even then, it is a good idea to double-check the output
of these scripts a number of times, before letting them
output YAML that would go straight to production.
This might warrant even more work; more than you might want
to invest.

![Is it worth the time to automate?](https://imgs.xkcd.com/comics/is_it_worth_the_time.png)

*This table (courtesy of [XKCD](https://xkcd.com/1205/)) tells
us how much time we can spend on automation before it gets
less efficient than doing things by hand.*

I'm a huge fan of automation. Automation is great. But
before I automate something, I need to be able to do it ...


### ... Manually

The best way to understand how these tools work, is to
do their job ourselves, by hand.

Just to make it clear: I'm not suggesting that you do this
on all your apps (especially if you have many apps!), but
I would like to show my own technique to convert a Compose
app into Kubernetes resources.

The basic idea is simple: each line in our Compose file
must be mapped to something in Kubernetes. If were to
print the YAML for both my Compose file and my Kubernetes
resources, and put them side by side, for each line
in the Compose file, I should be able to draw an arrow
pointing to a line (or multiple lines) on the Kubernetes side.

This helps me to make sure that I haven't skipped anything.

Now, I need to know how to express every section,
parameter, and option in the Compose file. Let's see
how it works on a small example!


```yaml
# Compose file                                                      | translation
version: "3"                                                        |
  services:                                                         |
    php:                                                            | deployment/php
      image: jpetazzo/appthing:v1.2.3                               | deployment/php
      external_links:                                               | service/db
      - 'mariadb_db_1:db'                                           | service/db
      working_dir: /var/www/                                        | ignored
      volumes:                                                      | \
      - './apache2/sites-available/:/etc/apache2/sites-available/'  |  \
      - '/var/logs/apptruc/:/var/log/apache2/'                      |   \
      - '/var/volumes/appthing/wp-config.php:/var/www/wp-config.php'|    \ volumes
      - '/var/volumes/appthing/uploads:/var/www/wp-content/uploads' |    /
      - '/var/volumes/appthing/composer:/root/.composer'            |   /
      - '/var/volumes/appthing/.htaccess:/var/www/.htaccess'        |  /
      - '/var/logs/appthing/app.log:/var/www/logs/application.log'  | /
      ports:                                                        | service/php
      - 8082:80                                                     | service/php
      healthcheck:                                                  | \
        test: ["CMD", "curl", "-f", "http://localhost/healthz"]     |  \
        interval: 30s                                               |   liveness probe
        timeout: 5s                                                 |  /
        retries: 2                                                  | /
      extra_hosts:                                                  | hostAliases
      - 'sso.appthing.io:10.10.22.34'                               | hostAliases
```

This is an actual Compose file written (and used) by one of my
customers. I replaced image and host names to respect their
privacy, but other than that, it's verbatim. This Compose file is
used to run a LAMP stack in a preproduction environment on a
single server. The next step is to "Kubernetize" this app
(so that it can scale horizontally if necessary).

Next to each line of the Compose file, I indicated how I
translated it into a Kubernetes resource. In another post
(to be published next week), I will explain step by step the
details of this translation from Compose to Kubernetes.

This is a lot of work. Furthermore, that work is specific to
this app, and has to be re-done for every other app!
This doesn't sound like an efficient technique, does it?
In this specific case, my customer has a whole bunch of
apps that are very similar to the first one that we
converted together. Our goal is to build an app template
(for instance, by writing a [Helm](https://www.helm.sh/) Chart)
that we can reuse, or at least use as a base, for many
applications.

If the apps differ significantly from each other, there
is no way around it: we need to convert them one by one.

In that case, my technique is to tackle the problem
by both ends. In concrete terms, that means converting
an app manually, and then think about what we can adapt
and tweak so that the original app (running under Compose)
can be easier to deploy with Kubernetes. Some tiny changes
can help a lot. For instance, if we connect through another
service through a FQDN (e.g. `sql-57.whatever.com`),
replace it with a short name (e.g. `sql`) and use a
Service (with an ExternalName or static endpoints).
Or use an environment variable to switch the code behavior.
If we normalize our applications, it is very likely that
we will be able to deal with them automatically with Kompose
or Docker Enterprise Edition.

(This, by the way, is the whole point of platforms like
OpenShift or CloudFoundry: they restrict what you can do
to a smaller set of options, making that set of options
easier to manage from an automation standpoint. But I
digress!)


## Conclusions

Moving an app from Compose to Kubernetes requires transforming
the application's Compose file into multiple Kubernetes resources.
There are tools (like Kompose) to do this automatically, but
these tools are no silver bullet (at least, not yet).

And even if we use a tool, we need to understand how it works
and what it's producing. We need to be familiar with Kubernetes,
its concepts, and various resource types.

{% include ad_en_long.markdown %}

*In the second part of this article (to be published
next week), we will dive into the
technical details and explain how we adapted this LAMP application
to run it on Kubernetes!*