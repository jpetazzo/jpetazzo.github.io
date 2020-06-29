---
layout: post
title: Streaming tech talks and training / Using Linux
---

If you are using Linux as your main operating system, you might
wonder if it's doable to use it to stream content, and how.
In this article, I'll tell you everything I learned about this:
what works, what doesn't, and the various hacks that I'm using
to keep it working.

This will be interesting if you are using (or want to use)
Linux for these things, but there will be also technical
tidbits (related to e.g. USB webcams) that you might find useful
even if you're using other systems.

We're going to talk about:
- supporting multiple webcams on Linux
- USB bandwidth challenges
- leveraging NVENC (NVIDIA's GPU-accelerated encoding)
  for H264 parallel encoding
- V4L2 and ALSA loopback devices, with or without OBS
- using and abusing `ffmpeg` for various purposes
- run a bunch of things in Docker containers because why not

It'll be *fun!*


## TL,DR

The short version is that Linux is a robust platform to stream
video. As often with Linux, the user interface can be a bit less
polished and I often had to learn more than I wanted to know
about some parts of the system. However, it offers a lot of
flexibility and you can combine things in very powerful ways.

If the previous paragraph let you wondering "what does that
exactly mean?", I will give you a little example. I'm using
a [Stream Deck] to change scenes with [OBS Studio]. Each button
on the Stream Deck is a tiny LCD screen. I'm told that on
macOS and Windows, you can set things up so that the scene
change buttons actually show a tiny preview of the scene
that you're about to change to. On my setup, these buttons
just show a dull, boring text string. However, I am able
to take the video stream that comes out of OBS, encode it
with 4 different video bitrates using GPU acceleration,
send these streams to various platforms like Twitch or
YouTube, record locally the highest bitrate, while also
sending it to another computer on my network that will
rebroadcast it to a Zoom or Jitsi meeting. (Not because it's
fun, but because I *actually* need these features sometimes.)


## Install this

I'm going to suggest that you run various commands to
see by yourself how things work. If you want to follow
along, or generally speaking,
If you want to tinker with video on Linux, I recommend
that you install:

- `v4l-utils` or `v4l2-utils` or whatever package
  contains the program `v4l2-ctl`, a command-line
  tool to list information about webcams and tweak
  their settings (like autofocus and such)
- `guvcview`, a handy GUI tool to preview a webcam,
  but also to tweak webcam settings while the webcam
  is in use under another program
- `ffmpeg`, the ultimate video swiss-army knife,
  to convert files but also encode in real
  time, stream, transcode, and much more

You might also want to get:

- `v4l2-loopback`, a kernel module that implements
  a virtual webcam
- `obs-v4l2sink`, an OBS plugin to send video to
  a V4L2 device (like the virtual webcam above)
- `gphoto2`, if you want to try to use a DSLR
  as webcam (of course it only works on some models)


## V4L2

On Linux, webcams use V4L2. That stands for "Video For Linux,
version 2". Every USB webcam that you plug into your
system (as well as other video acquisition devices) will
show up as a device node like `/dev/video0`.

On all the laptops that I used so far, the built-in
webcam was actually a USB webcam, by the way.

All the USB webcams that I worked with actually
showed up as *two* device nodes. The first one is
the one from which you can get the actual video stream.
The second one only yields "metadata". I don't know
what kind of metadata. I wasn't able to do anything
useful with that other device node, so I just ignore it.

You can check it out for yourself and list your webcams
like this:

```bash
v4l2-ctl --list-devices
```

If you have at least one webcam, it should be on
`/dev/video0`, so there is a good chance that you can
run the following command to see a preview of that
webcam:

```bash
ffplay /dev/video0
```

This should open a window with a live preview of the
webcam, and output a bunch of information in the
terminal as well.
For instance, on my laptop, I see this:

```
Input #0, video4linux2,v4l2, from '/dev/video0':B sq=    0B f=0/0
  Duration: N/A, start: 437216.677903, bitrate: 147456 kb/s
    Stream #0:0: Video: rawvideo (YUY2 / 0x32595559), yuyv422, 1280x720, 147456 kb/s, 10 fps, 10 tbr, 1000k tbn, 1000k tbc
```

What's particulary interesting is the
`yuyv422, 1280x720, 147456 kb/s, 10 fps` bit.

1. `yuyv422` is the pixel format. While most screens
   work with RGB data (since they have actual red, green,
   and blue pixels), video acquisition and compression
   often works with [YUV].
   Y is luminance (brightness), U and V are chrominance
   (color). Our eyes are more sensitive
   to changes in brightness than to changes in color,
   so YUV formats often discard some of the U and V
   data to save space without losing much in quality.
   That particular pixel format requires 16 bits per
   pixel (instead of 24 for RGB).
2. `1280x720` is the current capture resolution.
3. `10 fps` is the current capture frame rate:
   10 frames per second.
4. `147456 kb/s` is the data transfer, corresponding
   exactly to 1280 pixels x 720 lines x 16 bits per pixel
   x 10 frames per second.

That data transfer information is important, because many
webcams are USB 2, which is limited to 480 Mb/s. This is
a significant limiting factor, as we are about to see.


## The USB rabbit hole

You might have noticed that in the example above, we have
"only" 10 frames per second. This is a bit low, and we
can probably see that the video is a bit choppy.
(TV and movies are typically 24 to 30 frames per second.)
How can we get more?

Easy: use the `-framerate` option with `ffplay`. This
instructs `ffplay` to try and open the device with
extra parameters to achieve that frame rate.
Our command line becomes:

```bash
ffplay -framerate 30 /dev/video0
```

On my system, we get *exactly* the same result as earlier
(10 frames per second), with a message telling us:

```
The driver changed the time per frame from 1/30 to 1/10
```

This is because we asked a frame rate and resolution
too high for the webcam, or rather, its USB controller.
The formula that we used above tells us
that we would need 442 Mb/s for a raw, 30 fps video; but
that's just the video data. We need to add the overhead
of the USB protocol. And even if we manage to stay
below 480 Mb/s, we're dangerously close to it, and the
USB chipset in the webcam might not be able to pull it off.

So, how do we get a higher resolution *and* frame rate?


### Compressed formats

Most webcams can use compressed formats as well, and that's
what we need here.

To see the various formats that our webcam can handle, we
can use `v4l2-ctl --list-formats`, which on my built-in
webcam, yields the following list:

```
	[0]: 'YUYV' (YUYV 4:2:2)
	[1]: 'MJPG' (Motion-JPEG, compressed)
```

My webcam (and all USB webcams I've seen so far) can send
compressed frames in [MJPEG]. MJPEG is basically a sequence
of JPEG pictures. It is widely supported, it is significantly
more efficient than raw pictures, but not as efficient as other
formats like H264, for instance.
With MJPEG, each frame is an entire, independent frame.
More advanced codecs will 
use interframe prediction and motion compensation,
and they will send *groups of pictures* ([GOP] in short)
consisting of a whole image called an *intra frame*
followed by *inter frames* that are basically small "diffs"
based on that whole image.

Each webcam (and capture device) advertises a full list of
resolution, formats, and frame rates that it supports.
We can see it with `v4l2-ctl --list-formats-ext`.

We can tell `ffmpeg` to use a different format with
the `-pixel_format` flag. That flag requires to use
a format code. The format codes don't quite match
what `v4l2-ctl` tells us. For MJPEG, we should use `mjpeg`,
not `MJPG`. To see these format codes, we can run
`ffplay -list_formats all /dev/video0`. The pixel
formats will be shown at the end:

```
[video4linux2,...] Raw       :     yuyv422 :           YUYV 4:2:2 : 640x480 ...
[video4linux2,...] Compressed:       mjpeg :          Motion-JPEG : 640x480 ...
```

The format codes are `yuyv422` and `mjpeg`.

(Note that `ffmpeg` also shows us the supported resolutions,
which is nice; but it doesn't show the supported frame rates,
which is why `v4l2-ctl` is more useful in that regard.)

On my system, the following command will grab video
from the webcam using MJPEG:

```bash
ffplay -framerate 30 -pixel_format mjpeg /dev/video0
```

If you don't get the full resolution of your webcam,
it might be because you used it previously (in another
program) at a different resolution. It looks like unless
instructed otherwise, the device keeps whatever resolution
it had last time. You can change the resolution with
the `-video_size` flag, like this:

```bash
ffplay -framerate 30 -pixel_format mjpeg -video_size 1280x720  /dev/video0
```

You might notice that `ffplay` doesn't tell us anymore the
bitrate of the video, because MJPEG doesn't yield a
constant bitrate: each frame can have a different size.


### MJPEG and OBS Studio

In OBS Studio, the problem will manifest itself quite
differently. On the three machines where I tried it,
when I add a webcam in OBS, I can set the resolution,
frame rate, and a "Video Format".

The "Video Format" gives me a choice that looks like this:
- YUYV 4:2:2
- BGR3 (Emulated)
- YU12 (Emulated)
- YV12 (Emulated)

The first entry corresponds to the raw uncompressed
format. The three others (with the `(Emulated)` annotation)
crrespond to formats that are converted on the fly.
As it turns out, picking one of the "emulated" formats
will configure the webcam to use MJPEG, and convert
it to one of these formats.

When I try to use the uncompressed format with a
frame rate and resolution that aren't supported,
the video for that webcam freezes. As soon as
I switch to a lower frame rate, lower resolution,
or to an emulated format, it unfreezes.

So we definitely want to use one of the emulated
formats, unless we're happy with a smaller resolution
or lower frame rate, of course.


### BGR3, YU12, etc.

When we stream or record video, it will almost always
be YUV. However, when it gets displayed on our monitor,
it will be RGB. Most video cards can convert YUV to RGB
in hardware. With that in mind, it would make sense
for OBS Studio to use YUV internally. This would save
CPU cycles by avoiding superfluous RGB/YUV conversions,
except to display the video preview on screen, which
could be hardware-accelerated anyway.

However, I don't know how OBS Studio works internally.
I don't know if its "native" internal format is RGB or YUV.
I didn't notice any difference in video quality or in
CPU usage when switching between BGR3 and YU12, but
my tests weren't very scientific, so feel free to check
for yourself.


### Buffering

I experienced random lag issues with OBS Studio,
especially after suspend/resume cycles. For instance,
one camera would appear to lag behind the others,
as if it had a delay of a few tenths of second.

The "fix" is to change the resolution or frame rate.
It's enough to e.g. change from 30 to 15 fps, and then
back to 30fps. Somehow it resets the acquisition
process.

I recently tried to uncheck the "Use buffering"
option in OBS, and it *seems* to solve the problem
(I didn't experience lag issues since then) without
adverse effects.


### About USB hubs

If you're using USB 2 webcams and are experiencing
issues, try to connect them directly to your computer.
I've had issues (at the highest resolutions and frame
rates) when connecting multiple webcams to the USB
hub on my screen. It seemed like a good idea at first:
being able to plug the webcams into the screen simplified
wiring. However, the webcams are then sharing the
USB bandwidth going from the hub to the computer.

The problems can even appear when the webcam is the
only device plugged into the hub. Even worse: I've
seen one webcam fail when plugged into *some* ports
of my laptop's docking station, but not others.

It turns out that some ports of that docking station
were root ports, while others were actually behind
an internal hub. (This is similar to what you get
when you buy a 7-port USB hub; it isn't actually
a 7-port hub, but two 4-port hubs, the second one
being chained to a port of the firts one.)

Note that using USB 3 hubs or a fancy docking station
won't help you at all, because USB 2 and USB 3
use different data lanes. If you plug some USB 2
webcam (like a [Logitech C920s]) into a fancy
USB 3 hub that has a 10 Gb/s link to your machine,
all USB 2 (and USB 1) devices on that hub are
going to use the USB 2 data wires going to
the computer, and will be limited to 480 Mb/s total.

All these bandwidth constraints may or may not
affect you at all. If you're running a single webcam
in MJPEG behind a couple of hubs, you'll probably
be fine. If you are running multiple webcams and/or
at full HD or 4K resolutions and/or behind multiple
hubs shared with other peripherals (keyboard, mouse,
audio interfaces), it's a different story.
If you want to rule out that kind of issue, try
connecting the webcam directly to the computer.
If your computer has both USB 2 and USB 3 ports,
use USB 3 ports (even if the webcam is USB 2) because
on some computers, the USB 2 ports are already behind
a hub.


### USB 3 and USB-C

USB 3 offers much faster speeds. It starts at 5000 Mb/s,
so 10x faster than USB 2, woohoo!

Webcams supporting USB 3 shouldn't be affected by
all the bandwidth issues mentioned above. So if you
intend to have multiple cameras and super high resolutions,
try to get USB 3 stuff. (Note, however, that if your
goal is to improve video quality, you should first invest
in lights and other equipment, as mentioned in [part 2]
of this article series.)

"How can I know if my stuff is USB 3?"

USB-C connectors (the rounded ones on modern laptops,
phones, etc.) almost always indicate USB 3. (All the
USB-C connectors I found on computers and webcams were
USB 3. However, some cables have USB-C connectors but
are only USB 2. Tricky, I know.)

For USB A connectors (the older rectangular ones),
USB 3 is generally indicated by the blue color or by
the SuperSpeed logo as shown below.

![USB Type-A plugs and jacks](/assets/usb-type-a.jpg)


### `usbtop` doesn't work

While troubleshooting my USB bandwidth problems,
I found a tool that seemed promising: `usbtop`.
It shows the current USB bandwidth utilization.

Unfortunately, it made me waste a lot of time,
because it showed numbers that were *way smaller*
than reality, leading me to believe that I had
a lot of available bandwidth, while my bus was,
in fact, almost saturated.

I realized the problem when grabbing raw
video output from a webcam. `ffplay` would give
me an exact number which I could very with a quick
back-of-the-envelope calculation, while `usbtop`,
alas, would show me some much smaller number.


## V4L2 is back with a loopback

Let's leave aside all that USB nonsense for a bit.

Linux makes it super easy to have virtual webcams,
thanks to the V4L2 Loopback device. This is a device
that looks like a webcam, except that you can also
send video to it.

V4L2 Loopback is not part of the vanilla kernel,
so you will need to install it. Look for a package
named `v4l2loopback-dkms` or similar; it should take
care of compiling the module for you.

I personally load the module with:

```bash
modprobe v4l2loopback video_nr=8,9 card_label=EOS1100D,OBS
```

This creates devices `/dev/video8` and `/dev/video9`.
They will show up respectively as `EOS1100D` and `OBS`
in webcam selection dialogs. (The first one is to use
a DSLR as a webcam, the second one is used to get
the video output of OBS and pipe it to whatever I need.)

In the examples below, I will assume that `/dev/video9`
is a V4L2 loopback device. Adapt accordingly.

For instance, here is how to [Rickroll] your
friends or coworkers during a Skype or Zoom call
and show them the video clip of Rick Astley instead
of your face:

1. Install YouTube downloader script:
   ```bash
   pip install --user youtube-dl
   ```
2. Download video:
   ```bash
   youtube-dl https://www.youtube.com/watch?v=dQw4w9WgXcQ
   ```
3. For convenience, rename it to a shorter filename, e.g.:
   ```bash
   mv *dQw4w9WgXcQ.mkv rickroll.mkv
   ```
4. Decode video and play it through loopback device:
   ```bash
   ffmpeg -re rickroll.mkv -f v4l2 -s 1280x720 /dev/video9
   ```
5. Check that it looks fine:
   ```bash
   ffplay /dev/video9
   ```
6. Go to Jitsi, Skype, Zoom, whatever, and select the
   virtual webcam (if you loaded the module like I mentioned
   above, it should show up as "OBS"). Enjoy.

Note that this only gives you video. We'll talk about audio
later.

Also note the `-re` flag that we used above: it tells `ffmpeg`
to read the input file at "native frame rate". Without
this option, `ffmpeg` would read our video as fast as
it can, resulting in a very accelerated Rick Astley
in the output.

One more thing: if you want to play the video in a loop,
add `-stream_loop -1`. You're welcome.


### Good resolutions

You might have noticed in the example above that I resized
the video to 720p. Without the `-s 1280x720` we would get
full HD, 1080p (1920x1080) output. This is mostly fine
(in my experience, Zoom supports it) but many web-based
video systems (like Jitsi) limit resolutions to 720p
and below. If we hadn't resized the video, our virtual
webcam would advertise a picture size of 1920x1080,
and Jitsi would filter it out, and our "OBS" virtual
webcam wouldn't show up. (Thanks to the folks at Mozilla
who helped me figure that out by the way. They've been
incredibly helpful!)

Furthermore, the V4L2 Loopback device only supports one resolution at
a time, and it won't switch as long as there is at least
one reader or one writer attached to it. Which means that
if you mess around a bit (e.g. if you do some tests with
1080p video and open some WebRTC test page) your browser
might keep the video device open, and it would be stuck
in 1080p. `ffmpeg` would still send the video in whatever
resolution you tell it, but now that would be invalid
(and the `ffplay` test would yield garbled video output,
because `ffplay` would still see a 1080p device).
To troubleshoot that kind of issue, you can run `fuser -auv
/dev/video9` to see which processes are currently
using the file, and restarting your browser if necessary.


### Sending OBS output to a virtual webcam

If you want to use OBS with regular video conferencing apps,
you can use an OBS plugin called obs-v4l2sink. It will add
an entry "V4L2 Video Output" to the "Tools" menu in OBS,
letting you send OBS video to a V4L2 loopback device.
You can then use that loopback device in any app you want.

The resolution limit still applies: if you set up OBS
with a resolution of 1080p (or higher), the virtual webcam
may not happen in e.g. Jitsi and many other web-based systems.
If you plan on using these, change the "canvas size" in OBS
to a smaller resolution. (It will also significantly reduce
CPU usage, so yay for that!)

Also, note that most video conferencing systems don't handle
1080p, even when they boast "HD" quality.  As explained in
[part 3] of this series, Zoom will scale down webcam resolution
to 720p (or even lower), so sending 1080p output will be
completely useless.

This will be very noticeable if you share a browser or
terminal window this way. It will appear very pixellated
to your viewers, regardless of you're available network
bandwidth and CPU.

However, if you want to send 1080p output to Zoom
*and retain HD quality*, you can do it by using the
"window or desktop sharing" feature of Zoom.
When you share a window or desktop, Zoom switches
encoding settings to give you an outstanding picture
quality, at the expense of the frame rate.

You can try that by telling OBS to preview the video stream
in a window of that size (or a screen of that resolution),
then use the "share desktop" feature of Zoom to share that
window or screen.

Note that if you want to use that desktop sharing trick,
you don't need the V4L2 Video Ouput plugin, nor the V4L2 Loopback
module.

Sending OBS output to a virtual webcam (or to a screen and
then capturing that screen) is also a good way to grab
that output and then do whatever you want with it.
I use GPU acceleration to encode simultaneously 4
different bitrates, send them all to a broadcast
server, and save the highest one to disk, for instance.
(More on that later.)


## Using a DSLR or a phone as a webcam

Now that we familiarized ourselves with V4L2 Loopback,
let's see something more useful that we can do with it.

We'll see how to use a DSLR as a webcam, and how to
use a phone as a webcam.


### Using a DSLR as a webcam

I already mentioned this in [part 2] of this series.
The advantage of using a DSLR as a webcam is that it
should have a better sensor, and most importantly, better lenses.
If you have a good DSLR but with a basic lens, there is a good
chance that it won't be better than a decent webcam.
For instance, I tried with a [Canon EOS1100D], known as
the Rebel T3 in the US or the Kiss X50 in Japan;
and the image was actually worse than with my Logitech
webcams. But don't let that discourage you, especially
if you have a good lens kit!

One way to use a DSLR as a webcam is to use the HDMI
output, and an HDMI capture device. I already cover
that in [part 2] of this series, so I will talk about
another method here.

Many DSLRs support a "Live View" feature that can be
accessed over USB using a fairly standard protocol.
This "Live View" feature essentially gives a stream
of JPEG pictures ... so basically a MJPEG video stream.

To see if your DSLR supports it, connect it over USB
and run `gphoto2 --abilities`. If the output includes
"Live View", it will probably work. Otherwise, it
probably won't.

On the cameras supporting it, all we have to do is:

```bash
gphoto2 --stdout --capture-movie \
| ffmpeg -i - -vcodec rawvideo -pix_fmt yuv420p -threads 0 -f v4l2 /dev/video8
```

And now we can use `/dev/video8` in any application
expecting a webcam.

The [gPhoto remote] page has some details, and a long list
of cameras indicating if they are supported or not.

Note that the Live View typically has a much lower
resolution than the camera. On the EOS 1100D, it was
about 720p, so about 1 megapixel; much less than the 12 MP
that this camera is capable of.


### Using a phone as a webcam

You can also use a phone (or tablet) as a webcam.
Here are a few reasons (or excuses) to do that:
- you really want an extra camera for your multi-cam
  setup
- your main webcam is broken
- webcams are out of stock everywhere
- you have a bunch of old phones lying around
- you want to place the camera in a location that
  would make it difficult to connect it to the computer
  (or the wires would bother you)

In this example, we're going to use an Android app.
I'm pretty sure that similar apps exist on Apple
devices, but you'll have to find them on your own.

The app is [IP Webcam]. Install it, start it, then
at the bottom of the main menu, tap "Start server".
It will show a camera view and a connection URL
looking like "IPV4: http://192.168.1.123:8080".

You can go to that URL and click on "Video renderer: Browser"
to check that everything is fine.

The next step is to check with our favorite swiss-army
knife if it can read that video stream:

```bash
ffplay http://192.168.1.123:8080/video
```

This should display the video coming from the phone.
You might notice that the video starts lagging, and
that the lag increases. This is because the app is
probably sending at 30 fps, but `ffplay` thinks this is
25 fps, so it plays a bit slower than it should,
and it "gets late".

One way to address that is to force the frame rate:

```bash
ffplay http://192.168.1.123:8080/video -f mjpeg -framerate 30
```

Another way is to force immediate presentation
of frames as they show up:

```bash
ffplay http://192.168.1.123:8080/video -vf setpts=0
```

(The PTS is the "presentation timestamp", which tells
to the player *when* the frame should be displayed.
This can be manipulated to achieve slow-motion
or accelerated playback. Here, we set it to zero,
which apparently has the effect of telling `ffplay`
"omg dude you're late, you were SO supposed to display that frame,
like, *forever ago*, so do it *now* and we won't
tell anyone about it!")

Now we can shove that video stream into our virtual
webcam like this:

```bash
ffmpeg -i http://192.168.1.123:8080/video -pix_fmt yuv420p -f v4l2 /dev/video9
```

We don't need to meddle with the PTS here, because
by default, `ffmpeg` tries to read+convert+write
frames as fast as it can, without any concern for
their supposed play speed. You might see in the
output that it's operating at "1.2x" because it
computes that it's processing 30 frames per second
on a 25 frames per second video stream. Whatever.


## All hands on the Stream Deck

Getting the [Stream Deck] to work on Linux was
easy. There is a [Stream Deck UI] project that just works.

However, getting the Stream Deck to play nice with
OBS Studio was a different story. The Steam Deck UI
can be configured to generate key strokes, and OBS
Studio can be configured to use keyboard shortcuts.
However, for unknown reasons, on my machine, OBS
doesn't seem to recognize the key strokes generated
by the Steam Deck UI.

To work around the issue, I use [obs-websocket],
a plugin to allow OBS to be controlled through
WebSockets. Then I use [obs-websocket-py], a
Python client library to interface with that plugin;
and a little custom script called [owc] to invoke
that library from the command line. Then I set up
the Stream Deck UI to execute that script with the
right arguments.

I also use the [leglight] library and another
small custom script called [elgatoctl] to control
my [Elgato Key Light] from the command line
(and, by extension, from the Stream Deck).


## Audio

When using OBS, you have at least two options for audio:
route it through OBS, or bypass OBS entirely.
"Routing audio through OBS" means adding some "Audio Capture"
device in our OBS sources. "Bypassing OBS" means that
we do not add any audio device in OBS, and use a separate
tool to deal with audio.

If we stream or record directly from OBS, we must route audio
through OBS, so that the RTMP stream or the recorded
file includes audio.

Routing the audio through OBS is useful if you have e.g.
a waiting music, or if you want to mute the mic when switching
to specific scenes (like a "Let's take a break, we'll be right back"
scene).

Each time you add an audio source in OBS, you can switch
that source between three modes:

- Monitor Off (the default)
- Monitor only
- Monitor and Output

(You can find these modes by right-clicking on
the audio source in the "Audio Mixer" section, and
selecting "Advanced Audio Properties".)

"Monitor" means that OBS will play that audio input
back to you. This can be useful if you have an audio
source playing some background music, for instance.
You would then select "Monitor and Output" so that the
music goes to the RTMP stream *and* so that you can hear
it locally.

Be careful if you use simultaneously "Monitor",
speakers, and an active mic input: the monitored
audio input would play through the speakers and be
picked up by the mic.

This whole "Monitor/Output" situation becomes even
more confusing when you add PulseAudio to the mix
(no pun intended). PulseAudio lets you remap application
sounds to different outputs, so that you could e.g.
play that song on your speakers but hear that Zoom
call on your Bluetooth headset. Each monitored
channel shows up separately in PulseAudio. The computer
that I use for streaming has 3 audio interfaces and
a virtual one. Troubleshooting the whole audio pipeline
often turns into a wild goose chase.

Since I don't really need anything fancy on the audio side
(I just stream my voice), it is easier to directly route audio
inputs to the system that I use for conferencing or streaming,
rather than go through OBS. My mic is plugged into
a small USB interface that has a very distinctive
name (ATR2USB), so I just pick that one in e.g. Jitsi or Zoom;
and when streaming with `ffmpeg`, I set up `ffmpeg` to
directly grab audio from that interface.


### ALSA Loop

One thing that seemed promising was to use a virtual
[ALSA] loopback device. ALSA is a popular API to access
audio input/output on Linux. While many applications nowadays
use PulseAudio or [JACK] to access audio interfaces,
PulseAudio and JACK themselves generally use ALSA to
communicate with the hardware. ALSA is to audio what
V4L2 is to video: they're both low-level interfaces
to access respectively audio and video input/output
devices.

As you can guess from the title of this subsection,
there is an ALSA loop device, and it can be used
similarly to the V4L2 loop device.

For instance, we can configure OBS to send its audio
to an ALSA loop device, and then use this loop device
as a virtual mic in another application.

*At least in theory.*

In practice, if PulseAudio gets involved, good luck,
have fun.

The following command will load the ALSA loopback device:

```bash
modprobe snd-aloop index=9 id=Loopback pcm_substreams=1
```

`index=9` means that the loopback device will be ALSA
device "card 9". Again, I pick a number high enough
to avoid any conflicts with my existing audio interfaces.

`id=Loopback` will be the name of the card.

`pcm_substreams` indicates how many streams you want
that card to have. This is in case you want to have
multiple cards with multiple streams each. I might be
wrong, but I think that this *does not* correspond
to the number of channels. `pcm_substreams=1` seems
to give you a stereo channel. More research needed here.

After loading the loopback device, you can check that
it appears by listing input and output devices:

```bash
arecord -l
aplay -l
```

Since many webcams include microphones, the list of
capture devices can get quite large:

```bash
$ arecord -l
**** List of CAPTURE Hardware Devices ****
card 0: PCH [HDA Intel PCH], device 0: ALC298 Analog [ALC298 Analog]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: C920 [HD Pro Webcam C920], device 0: USB Audio [USB Audio]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 3: StreamCam [Logitech StreamCam], device 0: USB Audio [USB Audio]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 4: ATR2USB_1 [ATR2USB], device 0: USB Audio [USB Audio]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 9: Loopback [Loopback], device 0: Loopback PCM [Loopback PCM]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 9: Loopback [Loopback], device 1: Loopback PCM [Loopback PCM]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
```

The name of our device shows up correctly here, but
PulseAudio doesn't use it, and the ALSA loopback device shows
up as "Built-In Audio". Unfortunately, this is
exactly the same name as the *actual*
built-in audio interface, so good luck when trying to
distinguish them.

But the trickiest part is that we have one card with
two devices, each device sending to (and receiving from)
the other one. In my setup above,
if I send audio to ALSA device `hw:9,0`
I will be able to read it from `hw:9,1`, and vice versa.

By default, however, most (if not all) ALSA applications
will use the first device (`device 0`) of a given card. If you want
the ALSA loopback device to work for you, you need to
either explicitly write to device 1, or read from device 1.
Basically, you need to decide if you want to make your
life more complicated on the *sender* (playing audio) side,
or the *receiver* (recording audio) side.

In my case, if I want to record or stream audio with `ffmpeg`,
it is very easy to tell `ffmpeg` to read from `hw:9,1`,
so here is what I do:

1. Rename the audio interface in PulseAudio, so that it
   shows up in all applications as "Loopback":
   ```bash
   pacmd 'update-sink-proplist alsa_output.platform-snd_aloop.0.analog-stereo device.description="Loopback"'
   ```
2. Open e.g. `pavucontrol`, find OBS in the "Playback" tab,
   and assign it to the "Loopback" output.
3. Test audio playback with `ffplay -f alsa hw:9,1`,
   or use it as an input source in `ffmpeg` with
   `-f alsa -i hw:9,1`.

If you want to be able to use the loop device as an input
in Jitsi, Zoom, or whatever, you can try the following
additional steps:

4. Manually add the `hw:9,1` audio source in PulseAudio:
   ```bash
   pactl load-module module-alsa-source device=hw:9,1
   ```
5. Rename it to "Loopback":
   ```bash
   pacmd 'update-source-proplist alsa_input.hw_9_1 device.description="Loopback"'
   ```

Now you should see a "Loopback" option along your mics
and other audio inputs.

*Configuring PulseAudio to automatically load this module
and renaming audio inputs and outputs is left as an exercise
for the reader.*


## NVIDIA

If you have a NVIDIA GPU in your streaming machine, it
can be advantageous to use it to leverage hardware-accelarated
encoding (NVENC). In theory, this is great, because NVIDIA GPUs
are very efficient with that. In practice, proprietary drivers
get involved, and it's a tire fire, especially when using
multiple monitors. (The monitors have nothing to do with
hardware encoding; but proprietary drivers mess things up
pretty quickly in that regard.)

**Disclaimer:** it took me a while to find a
combination of drivers, options, video modes, etc. 
that would work and be stable and not randomly screw
everything up when rebooting or when suspending and
resuming. At one point, it took me 20 minutes of
rebooting, connecting/disconnecting screens, trying
various tools (between e.g. `xrandr` and the NVIDIA
control panel) until I got all my screens working
properly, because the procedure that I had used successfully
multiple times before just didn't work anymore.
My overall impression is that while the NVIDIA hardware
is pretty impressive, the software is at the other end
of the spectrum. That being said, if you're not afraid
of wrestling with proprietary drivers and dealing with
a lot of nonsense, let's see what we can do.


### Handling multiple monitors

When streaming, I use at least one external monitor,
preferably two (in addition to the internal monitor
of the laptop that I'm using). The laptop is a ThinkPad
P51 with a docking station. Both monitors are
connected to the docking station over DisplayPort.

On Linux, the usual way to deal with multi-monitor
setups is to use the RandR extension (unless you use
Wayland, but I'm going to leave that aside).
There is a command-line utility `xrandr`, a crude
but effective GUI called `arandr`, and you can use
a tool like `autorandr` to automatically switch modes
when screens are connected and disconnected.

This works alright when using the NVIDIA open source
drivers (`nouveau`), but in my experience, that doesn't
work very well when using the proprietary drivers.
It looks like the proprietary drivers *try* to implement
the RandR extension, but will fail randomly. At some
point, I almost had found a particular `xrandr`
command line that would work after booting the machine,
and another one that would work when resuming after
suspend - most of the time.

The most reliable method involves using `nvidia-settings`
in CLI mode to set NVIDIA *MetaModes*. MetaModes are
NVIDIA's proprietary way to handle multiple monitors.

This is what I'm using to scale the internal 4K LCD
to 1080p, and add one external monitor above the LCD,
and another one to the right:

```bash
TRANSFORM="Transform=(0.500000,0.000000,0.000000,0.000000,0.500000,0.000000,0.000000,0.000000,1.000000)"
LCD="DPY-4: nvidia-auto-select @1920x1080 +0+1080 {ViewPortIn=1920x1080, ViewPortOut=3840x2160+0+0, $TRANSFORM, ResamplingMethod=Bilinear}"
RIGHT="DPY-0: nvidia-auto-select @1920x1080 +1920+0 {ViewPortIn=1920x1080, ViewPortOut=1920x1080+0+0}" 
TOP="DPY-1: nvidia-auto-select @1920x1080 +0+0 {ViewPortIn=1920x1080, ViewPortOut=1920x1080+0+0}"
nvidia-settings --assign CurrentMetaMode="$LCD, $TOP, $RIGHT"
```

This seems to work in a deterministic way. I think I had
to restart the X session once because one screen didn't come up,
but otherwise this has been robust enough for my needs.


### NVENC

After installing the proprietary drivers, make sure that you
also have `libnvidia-encode.so` on your system. Then,
if you already know how to use `ffmpeg`, all you have to do
is replace `-c:v libx264` with `-c:v h264_nvenc` and you're
pretty much set.

Explaining the intricacies of H264 codecs, with profiles,
tuning, bit rates, etc. would be beyond the scope of this
article; but just for reference, here is the `ffmpeg`
command line that I'm using:

```bash
ffmpeg \
  -thread_queue_size 1024 -f alsa -ac 2 -i hw:4,0 \
  -thread_queue_size 1024 -f v4l2 -frame_size 1920x1080 -framerate 30 -i /dev/video9 \
  -c:a aac \
  -map 0:a:0 -ac:a:0 1 -b:a:0 128k \
  -map 0:a:0 -ac:a:1 1 -b:a:1 64k \
  -map 0:a:0 -ac:a:2 1 -b:a:2 48k \
  -c:v h264_nvenc -preset ll -profile:v baseline -rc cbr_ld_hq \
  -filter_complex format=yuv420p,split=2[s1][30fps];[s1]fps=fps=15[15fps];[30fps]split=2[30fps1][30fps2];[15fps]split=2[15fps1][15fps2] \
  -map [30fps1] -b:v:0 3800k -maxrate:v:0 3800k -bufsize:v:0 3800k -g 30 \
  -map [30fps2] -b:v:1 1800k -maxrate:v:1 1800k -bufsize:v:1 1800k -g 30 \
  -map [15fps1] -b:v:2 900k -maxrate:v:2 900k -bufsize:v:2 900k -g 30 \
  -map [15fps2] -b:v:3 400k -maxrate:v:3 400k -bufsize:v:3 400k -g 30 \
  -f tee -flags +global_header \
  [f=mpegts:select=\'a:0,v:0\']udp://10.0.0.20:1234|[select=\'a:0,v:0\']recordings/YYYY-MM-DD_HH:MM:SS.mkv|[f=flv:select=\'a:0,v:0\']rtmp://1.2.3.4/live/4000k|[f=flv:select=\'a:0,v:1\']rtmp://1.2.3.4/live/2000k|[f=flv:select=\'a:1,v:2\']rtmp://1.2.3.4/live/1000k|[f=flv:select=\'a:2,v:3\']rtmp://1.2.3.4/live/500k
```

(Sorry about these two very long lines; in practice,
I build them one piece at a time using a script.)

This will:

- acquire audio over ALSA device `hw:4,0`
- acquire video over the V4L2 device `/dev/video9`
  (the virtual webcam that comes out of OBS)
- encode audio in mono (it's just my voice, so I don't care
  about stereo) with 3 bit rates, providing high / medium / low
  quality
- encode video with 4 bit rates, using NVENC hardware encoding
- record the highest audio and highest video bit rates to
  a local file
- also send that high quality output over UDP to another
  machine on my LAN (10.0.0.20 in that example)
- generate 4 streams and send them over RTMP to a remote
  broadcast server (1.2.3.4 in that example)

The encoder is tuned here for low latency: it's using
the [Constrained Baseline Profile] to disable [B-frames].
The two highest bit rates have 30 frames per second and
a 1-second [GOP] size. The two lowest bit rates are
reduced to 15 frames per second and use a 2-second
GOP size. (This means higher latency when using [HLS]
streaming, but significantly improves quality.)

You can view GPU usage the `nvidia-smi` CLI tool.

On the other machine on my LAN (10.0.0.20), this
is how I receive the stream and "feed" it into a
virtual webcam for use with Jitsi, Zoom, etc.
as well as an ALSA loop device as described above:

```bash
ffmpeg -f mpegts -i udp://0.0.0.0:1234 \
  -f v4l2 -s 1280x720 /dev/video9 \
  -f alsa -ac 2 -ar 44100 hw:9,1
```

(The `-ac 2` lets us go back to stereo channels,
and `-ar 44100` resamples to 44.1 KHz, which
may or may not be necessary, but `ffmpeg` does
a much better job than PulseAudio when it comes
to resampling audio.)


### NVIDIA patch

One last thing about NVENC: NVIDIA artificially limits
the number of streams that you can encode in parallel.
For instance, with my GPU, I could get 3 streams,
but when I added the 4th one, I got an error message
similar to 
`OpenEncodeSessionEx failed: out of memory (10)`.

However, `nvidia-smi` said that I still had
*lots* of available memory (I had about 800 MB
GPU memory used over 4 GB).

Surprisingly, according to the [NVENC support matrix],
my GPU (a Quadro M2200 / GM206) is supposed to be "unrestricted".
I suppose that the detection code is broken, or that
the information on the NVIDIA website is invalid.

Still, since this is just a software restriction,
you can remove it by using [nvidia-patch], which will
patch your NVIDIA drivers to remove the limitation.

(If you're nervous about running nvidia-patch as root,
you can easily confirm for yourself that it's only
touching the NVIDIA `.so` files, and it's not replacing
them with new versions, but actually patching the binary
code with `sed`. While it's not technically impossible
that this would result in turning your GPU into a pumpkin,
it's probably okay-ish.)


## Docker

I run all the things described above in Docker containers.
This gives me a way to move the whole setup (including the
OBS plugins, which need to be compiled) to another machine
relatively easily.

There are many tricks involved, and I wouldn't recommend
that to anyone, except if you already have experience running
desktop applications in containers.

The Dockerfiles and the Compose file that I use is available
on my [obs-docker] repository on GitHub.


## Wrapping up

There are many quirks and tweaks involved to get
a good streaming setup up and running with Linux.
I don't know if things are easier on other systems.
It's generally easier to get started on a Mac or
Windows system; but customization is also harder
(or downright impossible).

For instance, hardware encdoding on a Mac
[seems pretty random](https://obsproject.com/forum/threads/question-about-hardware-encoding-for-macbook-pros-local-recording.107093/).
Windows obviously has first-class support for NVIDIA
GPUs, but if you want to encode multiple bit rates
at the same time like  I do, you probably have to break
out `ffmpeg` anyway.

If you're exploring the possibilities of streaming
content from Linux, I hope that this article could give
you some useful information!


{% include links_streaming_series.markdown %}
