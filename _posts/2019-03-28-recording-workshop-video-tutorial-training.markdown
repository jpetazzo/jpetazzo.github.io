---
layout: post
title: "Recording video tutorials with (almost) zero budget"
---


I've just published [a series of video of a one-day Kubernetes tutorial](https://www.youtube.com/playlist?list=PLBAFXs0YjviJwCoxSUkUPhsSxDJzpZbJd)
that I recently delivered in London. I would like
to share the method and tools that I used, because
although the result is far from perfect, I believe
it can be useful for other speakers who want to
share their work to a wide audience without a huge
investment (in time and equipment).


## What are we talking about?

I regularly deliver workshops, tutorials, and other
training sessions. The main topics are containers and
Kubernetes. Sometimes it is a half-day or full-day
workshop at a conference; sometimes a longer tutorial;
I also deliver public and private training for various
companies.

*Speaking of which ... Here is a message from our
sponsor (i.e. myself)!*

{% include ad_en_short.markdown %}

But in-person training doesn't scale, and I've always wanted
to reach a wider audience. A lot of high-quality courses
are now available online through various platforms.
Producing such a course is a lot of work; and for now,
I (unfortunately) don't have the resources to do that.

However, I thought that it should be easier to do a live
recording of a workshop, and then make the recording
available online. The result wouldn't be as good as
a real online course, but it would be better than nothing
(and it would get me one step in the right direction
if I ever decide to make such a course after all).


## First attempts

When I was working at Docker Inc., I started recording
the workshops I delivered at conferences. To keep things
simple, I decided that I would just do a screen recording.
Of course, having a camera is better (it's more engaging
to see the speaker) but it's also way more complex.

When using a Mac, I used Quicktime in "screen recording" 
mode; when using a Linux machine, I used vokoscreen.
I would stop the recording at each break (for coffee
and lunch) and start it again before resuming.
As a result, at the end of a one-day workshop, I would
typically have 4 files, each about 90 minutes long.

These files were a good start, and they were pretty
helpful for me to improve my workshops. I don't know
how it is for other speakers, but for me, *during*
the workshop, I always feel like there is one thousand
little things that I want to improve (for instance,
in the slides) but it's impossible to take good notes
while delivering the workshop at the same time.
The video helped me a lot with that.

However, I thought that nobody
would want to sit through a 90 minutes video. It's too long.
People probably want to know what's in the video, and they
want to go straight to the part that interests them.

So I wrote a Python script called [decoup](https://github.com/jpetazzo/decoup)
to help me slice and dice these video files. It works as
follows:

- first, I watch the video and write down the start/stop
  times of each section that I want to isolate, as well as
  the name of that section;
- then, I run the script, which uses ffmpeg to do the
  actual cuts, and spit out a number of separate short files.

I use MPlayer to zoom through the video content and
write down the start/stop times. It's pretty efficient,
and it typically takes me a few hours to go through one
day of content and break it down in sections of about
5 minutes. (The shorter the sections, the more breaks
you make, the longer it takes to write down the timestamps.)

If you want to see details about that process, you can
check the [decoup](https://github.com/jpetazzo/decoup)
repository on GitHub.

After getting a bunch of short video files, I upload
them to YouTube, and put them all in a playlist.

### First results

Here is the result for a [Docker Orchestration Workshop](https://www.youtube.com/playlist?list=PLBAFXs0YjviIDDhr8vIwCN1wkyNGXjbbc)
that I delivered in December 2016.

It was a good start! But the sound wasn't great.
I was recording using my laptop's built-in microphone,
so the sound would go up and down when I moved around
the podium; and when I typed on the keyboard, the
keystrokes were really loud. A lot of people brought that
up, and I have to admit that it can quickly get on your
nerves; even more so when you listen with headphones.

So, I wanted to improve the sound quality.


## Improving the sound quality

*Spoiler alert: I tried a number of microphones.
(No, not the [Propellerheads song](https://www.youtube.com/watch?v=BH63ixKTLts)😎)*


### The Blue Yeti is a really nice USB mic

I asked around what people were using to record podcasts
and similar things, and I was suggested to try the
[Blue Yeti](https://www.bluedesigns.com/products/yeti/).
I got one, and I recorded myself delivering a very short
segment, featuring slides and demos (and therefore, some
fast keyboard action). I compared the sound obtained
with the internal microphone of a Macbook Air 12, 
the internal microphone of a Thinkpad T440s, and the
Blue Yeti. The Blue Yeti has various modes (mono/omni
directional, etc), I tried them all.

Alas, this microphone didn't help to isolate the sound
of my keyboard. Don't get me wrong: this microphone is
amazing. At some point, I set it to stereo and recorded
myself walking around the room while talking;
and when I played back
the recording with my headphones, I could locate myself
in space, and it was able to capture faint remote sounds
that I hadn't otherwise noticed. Really impressive!
But it also captured my keyboard really well, unfortunately.


### Hiring a pro

In September 2018, I delivered a bunch of Kubernetes
training sessions with [Enix SAS](https://enix.io/) and
we hired a pro to capture one session. He also interviewed
some of the students.

We had a high-quality camera filming both speakers
(there was me, but also [Alexandre Buisine](https://twitter.com/alexbuisine)),
wireless lapel mics, and I was also recording my screen
like before.

The videos that we got out of this are of very high quality.
Here are just a couple of examples. They are in French, but
it will give you an idea of the result:

- a [promo video](https://vimeo.com/299020884) to show
  the training venue and atmosphere;
- an explanation about [declarative and imperative models](https://vimeo.com/302847894).

The result is definitely worth it, but it's a lot of work:
you need an extra person *during* the workshop to film,
and then it's many, many, many hours of work *after* the 
workshop to produce the videos.

So I wanted to find something that I could do and re-do
without having to hire a pro each time.


### Multiple presenters

Quick aparté: delivering with a co-speaker can make things
really tricky if each speaker presents with their own 
laptop. Now we need the recording from both computers;
and if a speaker can intervene while the other is presenting,
capturing their voice is another added challenge.

I asked for advice to the best A/V tech I know,
[Joe Laha](https://twitter.com/joelaha). Joe has done
A/V for countless conferences and tech events; including
recording all the sessions from multiple editions of
[DevopsDays Minneapolis](https://twitter.com/devopsdaysmsp).
Alas, his verdict was loud and clear: if I want to record
multiple HDMI sources (and multiple audio inputs)
*reliably*, I need equipment that is (a) expensive (b) bulky.
(OK, to be fair, it's not *that* bulky, but bigger than
I want to fit in my suitcase when traveling.)

Of course, I should have listened to the pro.
But I wanted to see for myself, so
I bought a [tiny, cheap HDMI recorder](https://www.amazon.com/HDML-Cloner-Standalone-Lag-Free-Past-Through-Required/dp/B00TF9MCXU/).
Honestly, it's a nice little gadget, especially for that
price.
I connected it between my laptop and the videoprojector,
inserted an USB key, and voilà, it records my HDMI output.

I thought that I could combine it with a cheap HDMI
switcher, and that would give me a way to record
two presenters.

Problem: *sometimes*, the recording would stop. It's not
completely random; I think it happens when the output
device (the videoprojector) shuts down. And I think that
the projector shuts down when my computer screen saver
is on for too long. The recorder has a LED indicating 
when it is recording, but it's easy to forget about it.

And, it still doesn't solve the annoying keyboard noise.


### Get more microphones

We did a brief interview with
[Bret Fisher](https://twitter.com/bretfisher) at a
conference, and he used a couple of lapel mics
connected to his phone.
I thought it was a good idea, so I ordered
[a pair of cheap lapel mics](https://www.amazon.com/gp/product/B07CHCSLVC/) and gave them a try.

Good news: with these, the noise of the keyboard is
almost gone!

There are some downsides, though.

**Wires.** These are wired mics, meaning that I have
to remove or unplug them each time I want to walk away
from the podium (during the breaks, for instance).
I found that it was only a minor inconvenience.
However ...

**No signal indicator.** Obviously, these are just
simple mics, so they don't have a LED or vu-meter
indicating the strength of the signal. This caused
me two problems. One time, when coming back from the
break, I didn't plug the mic correctly (the plug wasn't
all the way in). As a result, on the corresponding
video segment, there is no sound. Oops. Second problem,
since there is no vu-meter, it's hard to know if you're
recording at a correct level.
On some videos, my voice is clearly too
loud and saturates the input. It's not horrible, but
it could have been easily avoided. (By doing a quick
check with a program like `pavucontrol` or something
equivalent.)

**Hum.** This problem doesn't come from the mics
themselves, but rather from the mic input on the
laptop. On most laptops, these inputs are not
properly isolated. As a result, the recording has a 50 Hz
(60 Hz in the US) low frequency hum. Unfortunately,
disconnecting the laptop AC power didn't help; it turns
out that each time I got a hum, it came from the HDMI,
and since the HDMI goes to the projector, disconnecting
it is not really an option!

(Note: when my hands are resting on the keyboard's palm
rest, the hum disappears almost entirely. So perhaps I
could work something out with e.g. an ESD bracelet?)


## Removing the hum

I thought it should be possible to filter out the hum,
since it has always the same level, is always in the same
frequency bands ...

There are a couple of noise filters in recent versions
of ffmpeg, but they are not documented properly (or, if
you prefer, I was too stupid to understand the docs)
and I wasn't able to get them to work.

However, sox has much better documentation, and I was
able to use it to automatically process all my video files.

Here are the steps if you're interested:

1. Using the "decoup" script mentioned above, isolate a few
   seconds of noise (i.e. a moment when I don't speak, and
   nobody speaks, and there is just the loud BZZZZ sound).
   Let's say this is `noise.mp4`.
2. Extract the sound track from that file:
   ```
   # This generates noise.wav
   ffmpeg -i noise.mp4 -vn noise.wav
   ```
3. Generate a "noise profile" from that file:
   ```
   # This generates noise.prof
   sox noise.wav -n noiseprof noise.prof
   ```
4. Extract the sound track that I want to process:
   ```
   # This generates video.wav
   ffmpeg -i video.mp4 -vn video.wav
   ```
5. Process it with the noise reduction filter:
   ```
   # This generates filtered.wav
   sox video.wav filtered.wav noisered noise.prof
   ```
6. Merge back the filtered audio track with the video:
   ```
   # This generates video.avi
   ffmpeg -i video.mp4 -i filtered.wav \
          -vcodec copy -acodec copy \
          -map 0:v:0 -map 1:a:0 \
          video.avi
   ```
7. Delete the temporary files:
   ```
   rm video.wav filtered.wav
   ```
8. Repeat steps 4-7 for all the other files to process.

I work with `.wav` files because sox cannot work directly
with compressed audio (at least, not with the audio format
that I have). At the end, I generate a `.avi` file because
it's a flexible container (it can hold the codec from the
`.wav` file, whereas a `.mp4` file wouldn't be able to).

It doesn't really matter to recompress the audio, since
I will upload it to YouTube, and YouTube will recompress it
anyway.


## Upload to YouTube

The most painful part of the whole process is the upload.
I couldn't find an easy way to *sort by name* the videos
in a playlist. I had scripted it a while ago (using Google
Spreadsheets, sic!) but I couldn't find the script this time.
So I had to drag all the videos at the right place, one by
one.

Ideally, I would also need to edit descriptions and titles
*en masse*, and this doesn't seem to be possible. I saw
a few products that will do it for $$$. I might end up
buying one of these, but I would prefer something that I
can script easily.

## Next steps

My friend [Sébastien Wacquiez](https://twitter.com/swacquie)
(who helped a lot with the logistics for our training
sessions in Paris) strongly recommended that I use
high-quality, wireless mics. I agree that it would be nice,
but when I deliver a workshop by myself (without anyone
to help me), I don't have much time during the breaks,
so I'm not even sure that I would have the time to change
the batteries.

I'm considering getting a USB lapel mic (this should get
rid of the hum, hopefully), or a nice USB audio interface.
The latter would hopefully have vu-meters (making sure
that I don't record silence!), and while it sounds a bit
overkill, I also do some music recording and mixing once in
a while, so it could serve these purposes as well.

Another option (that I will almost certainly do!) is to
display a small vu-meter in a corner of the screen. That
would hopefully help me to realize immediately when the
recording level is too high, or when something is not
plugged properly.

I hope that the end result (this [Kubernetes workshop video recording](https://www.youtube.com/playlist?list=PLBAFXs0YjviJwCoxSUkUPhsSxDJzpZbJd))
is helpful to many people who want to learn about Kubernetes.
And if you like that kind of content and want it delivered
to your team or organization, I can totally make that happen!

{% include ad_en_long.markdown %}
