---
layout: post
title: Streaming tech talks and training / Overview
---

In March 2020, I started delivering online training sessions (instead
of doing it in person). In these series of blog posts, I describe how
I've set up what I call my "video streaming studio", hoping that my
experience and feedback can be useful to others.

In this first article, I'll give some context so that you can
understand what I'm doing and what I'm trying to achieve.

The second article will describe the hardware equipment that I'm using:
computers, cameras, lights, and so on.

The third article will describe the general software setup.
I'm using [OBS Studio] and I will explain
what I do with it, how, and why.

The fourth article will describe how I got that to work on Linux.
The first articles can be useful to you no matter which operating
system you use (OBS Studio is available on macOS and Windows as well).

Before we dive in, a little bit of context: I've been delivering
talks, workshops, training, for almost 10 years now, but it's been
my main source of income (as a freelancer) for a couple of years only.
I do not have any kind of formal training in audio or video production.
This means that I've certainly made some horrendous mistakes in my
choice of equpiment, software, and how I use them. Take everything
I wrote with a boulder of salt! If you have advice, suggestions,
questions, or any kind of feedback, you are welcome to
[contact me], I'd love to hear from you!


## What I do

For the last couple of years, I've been delivering Docker and
Kubernetes training, almost exclusively in person. I've done
private training (where a company hires me to train anywhere
from for 6 to 60 employees at the same time), public training
(where attendees pay per individual seat to attend), conference
training (where a conference organizer pays me to deliver a
workshop or tutorial at their event). I've also delivered
free workshops, spoke at meetups, and done a small number
of online presentations.

When I present to an audience, what people see on the projector
is a mirror of my screen. I do this because I constantly switch
between slides (that are designed to be presented full screen),
a command-line terminal (usually with a huge font, so that it's
easily readable even from the back of the room), and a web
browser (when showing demos or looking up extra information
or documentation).

I do not have a separate screen with speaker notes, because
it makes the switching (to the terminal and web browser) less
seamless.

It is certainly possible to deliver that kind of training using only
a laptop computer with its built-in webcam and sharing my
screen. But it is very hard to keep the audience engaged this
way for long period of times, so I wanted to up my game, so to
speak.


## Past attempts at producing video content

Since in-person training doesn't scale, I tried a few times
to record my classes. I've tried studio recording
(without an audience, at my own pace) and live recording.

I found studio recording to be extremely difficult given
my current skillset. I had to:
- record myself present the course, filming my face;
- record the hands-on sequences, labs, and demos separately;
- edit everything together (adding slides in the process).

At this point, this is not something that I can do.
I tried, and I failed. At best, I could produce 15 minutes
of content with 2 weeks of work; and the result wasn't
outstanding. It was very difficult to get demos and the
voice-over in sync. It required me to write down most of
what I wanted to say, and many, many takes; and a very
tedious editing proess.


## Live recording

Live recording seemed easier, because *in theory*, I would
just have to hit "record" and present the way I usually do.
In practice, of course, things are different.

I wrote another blog post about [recording workshop videos
with almost no budget](http://jpetazzo.github.io/2019/03/28/recording-workshop-video-tutorial-training/) that describes my experiences
and the process that I used.


## Streaming

Before the COVID-19 outbreak, I didn't think I would like
(or be able) to deliver my courses online. In March 2020,
when it became obvious that in-person training wasn't going
to happen in the near future, I decided to get some equipment
and get into streaming and online courses.

Hindsight is 20/20: streaming is a great format, in the sense
that it makes some of my previous technical problems go away.
Streamers are not expected to pace on stage, so there is no
need for a camera operator to keep you in frame. There is also
a lot of equipment, software, and platforms available for
streamers, so I'm not in uncharted territory.

The expectations are also different. I think about it like
music recorded in a studio vs performed live. I tend to be
more demanding and notice problems more in recorded music
(because the sound quality is also better), while being
simultaneously more forgiving, and more easily moved, by
live music. I imagine that my audience will also be more
forgiving with live content, where the expectations are
different: lower expectations in terms of video quality
(because we understand the technical constraints of streaming
live video feeds) but higher expectations in terms of
interactivity (because that's the whole point of a live
streaming). That's great, because the interaction and Q&A
are precisely the parts that I'm comfortable with!


## Results

If you want to see what my online talks look like, here
are a couple of examples:

- [Troubleshooting Troublesome Pods]
- [FiqueEmCasaConf]

(Note that in both cases, the quality is not as good as it
could be, because I was streaming to a third person who was
then re-streaming it to YouTube Live. I hope to have "direct"
streams soon too, with hopefully a better quality!)


## What's next

In [part 2], I will describe the equipment that I am using
or that I have tried.

In [part 3], I will describe my software setup. It's based
on OBS Studio, which is available on Linux, macOS, Windows.

In [part 4], I will describe how I got OBS (and associated
paraphernalia) to run on Linux. In fact, I even got
everything running in Docker containers, and I'll
also explain why.

{% include links_streaming_series.markdown %}
