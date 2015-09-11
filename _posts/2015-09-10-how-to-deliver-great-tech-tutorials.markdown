---
layout: post
title: How to deliver a great tech tutorial
---

Here are a few tips and tricks that I learned when building then delivering
the Docker Fundamentals course at Docker Inc. This course is a 2 days training
designed to be delivered to small groups (up to 20 people) but we also
delivered the intro part many times at tech conferences, to groups of varying
sizes (50 to 300).


## Foreword

I wrote this in a hurry. The style is probably not very good, and I should
probably move some parts around. Pull requests welcome :P 

Now, without further ado, here are all the things you could do to deliver
a great tutorial!


## Pre-provisioned cloud VMs

We did this for every single Docker tutorial: just before the tutorial (like,
the night before the tutorial, or even a few hours before it starts) we would
create cloud VMs, pre-provisioned with all the things the students will need.


### Constraints

You will need stable Internet access. Some people balked at the very idea
of doing the training on remote machines. "What if the conference WiFi
goes down?" In the case of Docker, we want to pull images, download
packages, etc.; so by doing things "in the cloud" we just maintain one
SSH connection per student, instead of having each student download
images and packages for 10s or 100s of MB.

At Velocity Santa Clara in 2014, we had 300 people in the room, and it
worked pretty well. Just clarify ahead of time to set expectations.


### How?

To automate the provisioning of the images,
we recommend to use cloud-init because it's ridiculously simple. In our
case, we start from an Ubuntu 14.04 image (all serious providers will have
this available; if not, switch to another provider), and we provide a
script as the cloud-init payload. (On EC2, that's the metadata field.)

The script gets executed at first boot. In our case, the script installs
the Docker Engine, Docker Compose, Docker Swarm, and pre-pulls a few images.
It also sets a custom user and password in the VM.

After provisioning the images, we have a script that gather the IP addresses,
and generates a printable HTML file that has little cards, one per machine,
showing IP address + login + password. We print that file, cut out the cards,
and hand them out to the students.


### Providers

We used successfully AWS EC2, Gandi, Digital Ocean. We don't endorse
a specific one. If you have a huge training (basically, if you need
100+ VMs) EC2 is slightly easier to deal with because you can provision
tons of VMs in a single API call, while with the others, you'll have to 
do loops (and it will take longer).

If you are on a budget and your tutorial is about an open source
project or a worthy cause, I recommend that you contact Gandi,
because while they don't do any kind of traditional advertisement,
they spend their marketing budget helping ethical projects and
the open source movement in general; so you might be able to
obtain a discount or some other kind of arrangement with them.


### Alternate methods

If you can't afford providing one VM per student, you can also
have VM images (VirtualBox recommended) that you will hand out
on USB keys, and have a smaller amount of VMs for people who
can't/won't use VirtualBox.

If you have a small amount of VMs and you don't want to print
credentials, you can also put the credentials in a shared
Google Spreadsheet and have people tick them off when they
use a VM.


## Prepare your material

Obviously, you want to prepare your material ahead of time.
Try to highlight the hands-on parts (i.e., the commands
that people are expected to run in the environments), so
that people who just want to "see it in action" can jump
straight to the point.

I'm a huge fan of keeping my presentation materials
in a repo, in diffable format. This means that PowerPoint
and Keynote are out. If you can afford the time investment
that goes with those tools, great! But unfortunately, I cannot.

(Note: I'm not saying that PowerPoint or Keynote are more
complicated to use, or require any particular kind of
training. What I'm saying is that in the long run,
maintaining a complex document, with successive versions,
bug fixes, collaborators, etc., turns out to be a nightmare
with those formats. By keeping my materials in markdown,
I can store them in a GitHub repo, accept pull requests, etc.)

I have used two different systems: showoff, and remark.
Remark is a simple markdown-to-HTML thing; you can see
an example in my [Docker orchestration workshop](
https://github.com/jpetazzo/orchestration-workshop/tree/master/www/htdocs).
I added a custom class for the hands-on sections,
so that people can identify them easily.

Showoff is way more advanced. You also write slides in
markdown, but when you will present them, you start
a custom server, that can be accessed in presenter
or viewer mode. The presenter has a fancy interface,
and viewers can "sync" their view to the presenter,
so that the slides auto-advance as the presenter goes
through the material. It's great if you want to go
the extra mile.


# Beta-test your material

Before the first delivery, enroll 1 or 2 "candid users"
to be your beta testers. Go through the material with
them at the expected pace. See what works, what doesn't.
Don't hesitate to make significant pauses to rehaul
content if you see that it really doesn't work.

If you are going to have TAs and must train them,
this is the perfect opportunity to do it!


## Put sample code on GitHub

If you can, put your material (slides) on GitHub.
If you cannot (e.g. if you make a living off your training
and that building the material represents a huge time investment
for you, and/or you're licensing that material), consider
putting the sample code on GitHub anyway.

Why? So that people can easily download it, refer to it,
and even fix it (through pull requests).

This is particularly important for any file exceeding a few lines,
or for code samples spread across multiple files. It's way faster
to `git clone` a sample repo, than to copy-paste multiple files,
or even worse, type them manually.


### Put *all* examples on GitHub

Something I learned recently: if your workshop has a section where people:

- start with some sample code that you provide;
- execute it;
- then tweak it and execute again;
- tweak it more;
- etc.

... Then you should consider providing *all* the successive versions
of the code. Either as files with different names, or maybe different
tags or branches in the repo; whatever suits your fancy.

This helps a lot; rather than having slides saying "and now you have
to change files X and Y so they look like this."


## Put your slides online during the training

If you can, have the slides available online during the training.
There are multiple advantages:

- it will help people that are far from the projector screen, 
  or have bad eyesight, or don't have a direct line of sight 
  to the projector screen...
- it will help people who are lagging behind a little bit,
  or who want to look ahead before asking a question
- it will help to copy-paste sample code rather than typing it


### My 2c tip

When I spin up the VMs for the students, I set one aside for
myself. I assign a DNS name for this VM (e.g. training.dckr.info)
and I deploy a small static web server on it, with the
material that I want to share. When the training involves
manager/worker topologies or any kind of setup where the
students have to refer to a well-known node, I make this VM
the well-known node, and I tell them to use the DNS name
(instead of the IP address, which is error-prone).


## Try to always have at least one TA

If you have more than 20-30 students, it's great to have a 
Teaching Assistant. When somebody is stuck, they can raise
their hand, and the TA will help them - instead of requiring
you to break the flow and stop everything to help them.

Also, when you notice things to fix (typos, commands that
don't work like expected...) it's great if the TA can
double as a scribe and take reliable notes. Those notes
will generally be better than the 3 cryptic keywords that
you'll jolt down on a scratch file or a post-it note.

Bonus point if the TA makes pull requests during the training,
so that immediately after, you can review and fix. The alternative
is to postpone that later, and then life happens and by the time
the next training is there you still haven't fixed the material!


## Review your changes

When you do significant changes (moving content around,
switching a tool for another...) make sure that you re-run
the whole material. It's very easy to forget a little detail
that will make the whole thing obscure (e.g. at some point
you decide to replace wget with curl, but you leave a few
references to wget in a few places, and now your students
are super confused!)


## Things I don't do, but you should

- satisfaction surveys
- follow-up emails
- *your suggestion here*

