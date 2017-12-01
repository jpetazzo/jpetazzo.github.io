---
layout: post
title: DevOps, Docker, and Empathy
---

Just because we're using containers doesn't mean that we "do DevOps."
Docker is not some kind of fairy dust that you can sprinkle around
your code and applications to deploy faster. It is only a tool,
albeit a very powerful one. And like every tool, it can be misused.
Guess what happens when we misuse a power tool? Power fuck-ups.
Let's talk about it.


I'm writing this because I have seen a few people expressing very
deep frustrations about Docker, and I would like to extend a hand
to show them that instead of being a giant pain in the neck, Docker
can help them to work better, and (if that's their goal) be an
advantage rather than a burden in their journey (or their
"digital transformation" if we want to speak fancy.)


## Docker: hurting or helping the DevOps cause?

I recently attended a talk where the speaker tried
to make the point that Docker was *anti-devops*, for a number of
reasons (that I will list below.)
However, each of these reasons was (in my opinion) not
exactly a problem with Docker, but rather in the way that it was
used (or sometimes, abused). Furthermore, *all* these reasons
were, in fact, not specific to Docker, but generic to cloud deployment,
immutable infrastructure, and other things that are generally
touted as *good* things in the DevOps movement, along with cultural
choices like cross-team collaboration. The speaker
confirmed this when I asked at the end of the talk, "did you
identify any issue that was *specific to Docker and containers*
and not to cloud in general?" — there was none.

What are these "Docker problems?" Let's view a few of them.


### We crammed this monolith in a container ...

*... and called it a microservice.*

In his excellent talk
["The Five Stages of Cloud Native"](https://youtu.be/NYv0kwlkwAY?t=14m30s),
[Casey West](https://twitter.com/caseywest)
describes an evolution pattern that he has
seen in many organizations when they adopt microservices.

Some of us (especially in the enterprise) are putting
multiple services in a container, including a SSH daemon
used for default access, and calling it a day.

Is this a problem? Yes and no.

Yes, it is a problem if we pretend that this is the final
goal of our containerization journey. Containers really shine
with small services, and that's why the Venn diagram of folks
embracing containers and folks embracing micro-services
has a pretty big overlap. We *can* `tar -cf- / ... | docker import`
and obtain a container image of your system. Should we?
Probably not.

Except if we acknowledge that this is just a first step.
There are many good reasons to do this:

- verifying that our code (and all associated services) runs
  correctly in a container;
- making it easier to run that VM in a local environment,
  to leverage the ease of installation of e.g. Docker4Mac
  and Docker4Windows;
- running that VM on a container platform, to be able to
  control and manage a mix of containers and VMs from an
  interface that "understands" containers;
- or even having a point-in-time snapshot of your system, that you
  will be able to start in a pinch in case of unexpected incident.

Docker Inc. has a program called "Modernize Traditional
Applications" (MTA in short), aiming at helping the
adoption of containers for legacy apps. A lot of people
seem to believe that this program is basically "import
all our VM images as containers and YOLO," which couldn't
be farther from the truth. If you're a big organization
leveraging that program, you will first identify the apps
that are the best fit for containerization. Then, there are
tools and wizards (like
[image2docker](https://github.com/docker/communitytools-image2docker-win))
to generate Dockerfiles, that you will progressively
fine-tune so that the corresponding service can be built
quickly and efficiently. The MTA program doesn't make this
entirely automatic, but it helps considerably in the process
and gives a huge jump-start.

Yes, some VMs might end up running, almost unchanged, as
containers; in particular for apps that don't receive updates
anymore but have to be kept running anyway. But if somebody
told you, "I'm going to turn all your VMs into containers
so that you can have more DevOps," you were played, my friend.

You know what? We had exactly the same challenge 10 years
ago, when EC2 became a thing. "We took our physical servers
and turned them as-is into AMIs and we are now making good
use of the cloud!" said no-one ever. Moving applications to
the cloud requires changes. Sometimes it's easy, and sometimes,
well, you have to replace this SQL database with an object
store. This is not a problem unique to containers.


### Shadow IT is back, with a vengeance

"Shadow IT," if you're not familiar with the term, is when Alice
and Bob decide to get some cloud VMs with the
company credit card, because their company IT requires them
to fill 4 forms and wait 2 weeks to get a VM in their data center. It's good
for developers, because they can finally work quickly;
it's bad for the IT department, because now they have
lots of unknown resources lying around and it's a nightmare
to manage and/or clean up afterwards. Let alone the fact that
these costs, seemingly small at first, add up after a while.

Since the rise of Docker, it's not uncommon to hear the
following story: our developers, instead of getting VMs
from the IT department, get *one giant big VM*, install
Docker on it, and now they don't have to ask for VMs
each time they need a new environment.

Some people think that this is *bad*, because we're
repeating the same mistakes as before.

Let me reframe this. If our IT department is not able
to give us resources quickly enough, and our developers
prefer to start a N-tier complex app with a single
`docker-compose up` command, perhaps the problem is
not Docker. Perhaps our IT department could use this
as an opportunity, instead of a threat. Docker gives
us fantastic convenience and granularity to *manage*
shadow IT. If we agree to let our developers run
things on EC2, we will have to learn and leverage
a lot of new things, such as access control with IAM and tagging
resources so that we can identify what belongs to
which project, what is production, etc. We could
use separate AWS accounts but this comes with other
drawbacks, like AZ naming, security groups synchronization...
With Docker, we can use a much simpler model. New project?
Allocate it a new Docker host. Give UNIX shell access to the
folks who need to use it. We all know how to manage that,
and we can always evolve this later if needed.

If anything, Docker is helping IT departments to have a more
manageable shadow IT, and that's good — because these
IT departments can now do more useful things than
provisioning VMs each time a developer needs a new
environment.

To rephrase with less words and the wit of
[Andrew Clay Shafer](https://twitter.com/littleidea):
["Good job configuring servers this year! … said no CEO ever."](
https://twitter.com/bridgetkromhout/status/889859980479926273)


### Persistent services, or "dude, where's my data?"

*"If you run a database in a container, when you restart
the container, the data is gone!"* That's false on many
levels.

The only way to really lose data is if you start your database
container with `docker run --rm` *and* the data is *not* on a
volume.

Of course, if you `docker run mysql`, then stop that container,
then `docker run mysql` again, you get a *new* MySQL container,
with a new, empty database. But the old database is still there,
only a `docker start` command away.

In fact, even if you `docker rm` the container, or run it
with `docker run --rm`, or run it through Compose and
execute `docker-compose down` or `docker-compose rm`,
your data will still be there, in a *volume*. This is because
all the official images for data services (MySQL, Redis, MongoDB,
etc.) persist their state to a volume, and the volume has to
be destroyed explicitly.

Of course, if you don't know this, and are just learning
Docker, you might freak out and wonder where is your data.
That's perfectly valid. But after looking around a bit, you'll
be able to find and recover it.

However, if you run in the cloud (say, for instance, EC2)
and are storing anything
on *instance store* ... Good luck. *Now* you can really lose
data super easily. You should have been using an EBS volume!
If you didn't know that, too bad, too late, your data is gone,
and all the Googling in the world won't get it back.
(Oh, and let's not forget that for at least half a decade,
EBS volumes have been
plagued with performance and reliability issues, and have even
caused [region-wide outages on EC2](https://aws.amazon.com/de/message/65648/).)

Bottom line: managing databases is way harder than managing stateless
services, because production issues can incur not only downtime,
but also data loss. To quote [Charity Majors](https://twitter.com/mipsytipsy),
["the closer you get to laying bits down on disk,
the more paranoid and risk averse you should be"](
https://twitter.com/mipsytipsy/status/935508331740905472).

No matter what avenue you choose for your databases
(containers, VMs, self-hosted, managed by a third party), take appropriate
measures and make sure you have a plan for when things go south.
(That plan can start with "backups"!)


### The tragedy of the unmaintained images

What happens if our stack uses the `jpetazzo/nginx:custom` image,
and that sketchy `jpetazzo` individual stops maintaining it?
We will quickly be exposed to security issues or worse.

That is, indeed, a shame. That would *never* happen with distro
packages! We would *never* use a PPA, and certainly not download
some `.deb` or `.rpm` files to install them from a second-hand
Puppet recipe.

Just in case you had a doubt: the last paragraph was pure,
unadulterated sarcasm. Virtually
every organization has an app that uses an odd package, installs
some library straight from somebody's GitHub repository `master` branch,
or relies on some hidden gem like
[left-pad](https://www.theregister.co.uk/2016/03/23/npm_left_pad_chaos/),
unknowingly lurkingin the bowels of a shell script hidden under
thousands of lines of config management cruft.

We can address all the bitter criticism we want to Docker and
the sketchy, unmaintained images that haunt the Docker Hub, but
realistically, Docker is not the first platform that allows
developers to share their work.

If we worry about our developers using unvetted Docker images,
I wonder: how do we check what they're using in requirements.txt,
package.json, Gemfile, pom.xml, and other dependencies?

In fact, Docker gives us significant improvements over the status
quo. Products like [CoreOS Clair](https://coreos.com/clair/docs/latest/)
or [Docker Security Scanning](https://docs.docker.com/docker-cloud/builds/image-scan/)
let us analyze images at rest, finding vulnerabilities without
requiring direct access to our servers. Read-only containers and
`docker diff` give us easy ways to enforce or check compliance
of our applications to make sure that they do not deviate.


### Works in my container — ops problem now

In the early days of Docker, "works on my machine - ops problem
now" was one of the memes used to convey the advantage of
Docker. Ship a container image! It will work everywhere.

According to some perceptions, however, the reality is different:

- we went from "blindly shipping
tarballs" to "blindly shipping containers";
- Docker put us back 5 years with regards to culture adoption.

These two points are very important. Let's discuss them in detail.


## Building empathy

Going from "works on my machine" to "works on my container" was
huge progress. 
In Spring 2015, I had the honor
of keynoting the TIAD conference in Paris; and I tried to show in
practical ways how we could use Docker to foster empathy between
teams, and break down silos. The
[presentation](https://www.youtube.com/watch?v=sDRbKcz3QWU)
was in French, but my
[slides](https://www.slideshare.net/jpetazzo/docker-automation-for-the-rest-of-us)
are in English. My core idea was built around a number of
specific experiences.

When I was doing customer support for dotCloud (the PaaS that
eventually pivoted to become Docker), I was constantly being
challenged by the variety of stacks and frameworks that our
customers were using. PHP (and half a dozen frameworks like
Laravel, Symfony, Drupal, etc.), Python (with Flask, Django,
Pyramid, just to name a few!), Ruby, Node.js, Perl, Java
(with all the variety of languages that you can run on top of
the JVM) — dotCloud could run all of them. When a customer
opened an issue, I had two options: try to reproduce it from
scratch (that's how I wrote my first Clojure program, by the way),
or ask the customer if I could clone their environment
(including the
[dotcloud.yml](https://github.com/jpetazzo/django-and-mongodb-on-dotcloud/blob/master/dotcloud.yml)
file, a distant paleolithic ancestor of the Compose file).
The latter would give me a huge head start to reproduce the
issue.

Imagine, as a customer, telling your support representative:
"When I do requests to S3 from my PHP webapp, they time out
once in a while; however, if I do that from the CLI, they
always work." Unless you give them access to your environment,
they are very unlikely to figure out what's going on.
However, if you write a tiny Dockerfile, and explain
"if you run `docker-compose up` and then `curl localhost:8000`
in a loop, you'll see the problem" — they are way more likely
to be able to help. And even if it works on their machine,
now at least you know that it's not a code / version / library
problem.

*Good luck achieving the same thing by hurling tarballs of code.*

It doesn't stop here. In too many organizations, it's alas
too frequent that communication between support and dev teams
is highly dysfunctional, with level 1-2 support engineers being
considered as a lower tier of engineers, because the "soft skills"
(aka "being a decent good human") that they have are devalued
in comparison to the "technical skills" of developers. As a result,
it can be difficult for support teams to get developers to acknowledge
issues, until they attract the attention of upper management.
Docker can be helpful here as well, because support teams can
reproduce issues in a containerized environment — thus providing
*functional tests*. It is then easier for the dev team to look at
these issues, because the "tedious work" (of reproducing the
problem in strictly controlled conditions) has been solved for them.


### Wait, couldn't we already do that before?

Of course. Reproducible environments with Vagrant, Puppet, etc. are
not a new thing. What's new is bringing the power of a Dockerfile
to a crowd that can't or won't learn how to use a configuration management
system.

The title of my TIAD keynote was "Docker: automation *for the rest of us*"
because I'm deeply convinced that it gives access to powerful tools
to a larger crowd.

Successfully embracing DevOps principles requires us to agree and
use some common tools and languages. Don't get me wrong: I'm not
talking about *technical* tools or *programming* languages.
But if the majority of the people supposed to "do DevOps" in our
organization are left on the side of the road because the tools that
we have picked are too complex for them, we won't get far in our
DevOps journey, and we won't digitally transform much.


## Harder Better Faster Stronger Docker

I recently found myself joking about the fact that "Docker lets
us go faster; but if we're facing a wall, we're just going to hit
it harder." I mean it. But I think that's *good*. Because it
means that we're going to *fail fast*, and we'll improve faster.
Which is one of the key points of DevOps. Shorten that feedback
cycle, because each iteration lets us improve the process. The
faster we iterate, the faster we improve.

One particular quote I’ve seen surprised me so much, that I wondered if it
was said seriously:

*"We had disciplined ourselves to work in
cloud environments, as close as possible to our production setups.
Docker allows us to work locally, in very different conditions;
it takes us 5 years back."*

My first thought was, "That person must be joking or trolling."
Docker gives us back the ability to work locally. If your team,
organization, or tooling, required you to work in the cloud, it
was taking you 25 years back, to the era of mainframes and minis.
We should celebrate a tool that lets us work locally, not decry it;
because we can work faster, without waiting for the CI pipeline
to pick up our commit and test it and deploy it to preprod just
to see a trivial change. (These steps should be mandatory when we
submit something to others for review, though.)

But velocity has a cost (and no, I'm not talking about the price of
conference tickets.)


## It's not about the tools, and yet ...

The amount of tools at our disposal keeps growing. We used to
joke about the multiplication of JavaScript frameworks, but
if you have an AWS account, log into the
[AWS console](https://console.aws.amazon.com) and have a look
at the number of services out there. Do you even know what
they all do? I don't. Go has barely solidified its place
as a language of choice for infrastructure projects, and
some of us are already trying to displace it with Rust.
Everybody and their dog is getting excited about Kubernetes,
but which one of its 15 different network plugins are we going
to pick when we deploy it? Docker has a boatload of features
at each release, but even I don't have the time to know
all of them. Should we look into Habitat, Flatpak, Buildah?

We don't have to keep up with everything, though. And more
importantly, we don't have to embrace new things at 1/10th
of the speed of light. As early as 2014, people were asking me
if "Docker was ready for production." It was ready — if you
knew what you were doing. Most oftentimes, my answer was:
"Start Dockerizing an app or two. Write a Compose file.
Empower your developers to use Docker. Set up CI, QA,
a staging environment. You will get a huge ROI in the process,
and by the time you're done, you will have acquired a huge
amount of operational knowledge about Docker, and you will
be able to answer that question on your own."

I feel bad for all the folks who went straight to production
without taking the time to consider what they were doing
and learn more about the technology. (Except the ones
doing high frequency trading on CentOS 6, because I do like
me a good joke.)

This is not specific to Docker. Today we laugh at the poor
souls who edit files on the servers, only to have them
overwritten by Puppet the next minute; forgetting that
years ago, we were these poor souls and we had no idea what
the hell was going on, persuaded that the computers were
conspiring against us.

Docker is not *the* perfect tool; but it's a pretty good one.
It brings to the masses (or at least, to a larger number)
lots of techniques that everybody wanted to implement, but
that only Netflix managed to get right. Today, with Docker,
a one-person-team can build artefacts for any language, run
them on their local machine whatever its operating system,
and deploy them on any cloud. And that's just a first step!

So instead of complaining that Docker is killing our DevOps
efforts, it would be more productive to explain how to
refactor the anti-patterns that we see out there.


## Containers will not fix your broken culture

(This is the title of an [excellent talk](https://bridgetkromhout.com/speaking/2016/springone-platform/)
by [Bridget Kromhout](https://twitter.com/bridgetkromhout),
covering these topics as well.)

If there is one point where I strongly agree, it's
that the DevOps movement is more about a culture shift
than embracing a new set of tools. One of the tenets
of DevOps is to *get people to talk together.*

Implementing containers won't give us DevOps.

You can't buy DevOps by the pound, and it doesn't come in
a box, or even in intermodal containers.

It's not just about merging "Dev" and "Ops," but also
getting these two to sit at the same table and talk to each other.

Docker doesn't enforce these things (I pity the fool who preaches
or believes it) but it gives us a table to sit at, and a common
language to facilitate the conversation. It's a tool,
just a tool indeed, but it helps people share context and thus understanding.

That's not too bad.

I'll take it.

*I would like to thank [Bridget Kromhout](https://twitter.com/bridgetkromhout) for giving
thoughtful and constructive feedback on an early version of that post. All remaining typos and mistakes are my own. I take full responsibility for what is written here; so please send complaints and rants my way!*
