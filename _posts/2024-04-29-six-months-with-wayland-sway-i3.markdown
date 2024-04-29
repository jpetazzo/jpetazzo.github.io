---
layout: post
title: "Six months with Wayland, from i3 to Sway"
---

Six months ago, I started using [Wayland] (the graphics stack that will replace X11 on Linux). This is a summary of what worked, what didn't, and a few tips and tricks for folks considering to do the same.


## TL,DR

- If you're using [i3] and want to try Wayland without reconfiguring everything, try [Sway]. Its configuration format is 99.99% compatible with i3, so you can easily switch back and forth between X11 and Wayland while maintaining a single configuration.
- If your machine has an NVIDIA GPU, don't bother - even if you don't use that GPU (e.g. if you have Intel+NVIDIA and use Intel to drive your displays). Here lies pain, random freezes, kernel panics, and bugs aplenty.
- With Intel or AMD GPUs, the experience is good. There are a few glitches but nothing horrible.
- It's possible to easily switch between Xorg and Wayland by logging in in text mode, and then running `startx`  or `sway` respectively. Really convenient if (like me) you don't care about having a "Desktop Manager".

Read on if you want the details.


## Context, environment...

I manage a handful of Linux machines, all running [Arch Linux]. There is a wide variety of GPUs:

|Machine    | L/D | Year | CPU          | iGPU               | dGPU                    |
|-----------|-----|------|--------------|--------------------|-------------------------|
|bolshoy    | D   | 2019 | Intel 9600K  | UHD Graphics 630   | NVIDIA GeForce GTX 1660 |
|hex        | L   | 2016 | Intel 6600U  | HD Graphics 520    | none                    |
|kater      | L   | 2020 | Intel 1065G7 | Iris Plus Graphics | none                    |
|red        | L   | 2024 | AMD 7840U    | Radeon 780M        | none                    |
|twister    | D   | 2023 | Intel 13600K | UHD Graphics 770   | none                    |
|zavtra     | D   | 2021 | AMD 4750G    | RX Vega            | NVIDIA GeForce RTX 3060 |

*L/D indicates Laptop or Desktop.*

They're used mostly for web browsing, text editing, running a bunch of containers and sometimes a small VM, play older games. These are fairly light requirements, and even the older laptop keeps up easily.

The desktop machines are also used in a slightly more demanding way: they drive two 4K monitors, and are used to stream my [Docker and Kubernetes live training sessions][training]. This means running OBS with 2 cameras, and encoding 5 video streams at 1080p/30fps (4 streams at constant bitrate for live broadcast, and 1 stream at constant quality for local recording).

I also sometimes run "machine learning stuff": speech-to-text with [Whisper], or image classification with [FMRACV] (a homemade image classifier built with Tensorflow). I also run this on GPU (it could run on CPU, but almost 100x slower).

Until mid-2023, I was using Xorg everywhere, and for the NVIDIA GPUs, I was using the NVIDIA proprietary drivers. I would use the open-source alternative [Nouveau] if I could, but unfortunately, it doesn't support video encoding nor CUDA (which is required for my ML workloads).

At some point in mid-2023, I decided to try Wayland (for the Nth time). I honestly don't remember what was the reason this time - perhaps screen tearing while playing [Factorio] in 4K, or something like that. Important stuff. 😅

My previous attempts with Wayland were very brief (it was mostly "start a composer; run a terminal and a web browser; rejoice; kill all processes and go back to Xorg"), but this time I wanted to use it as my daily driver and stick to it permanently - unless I ran into a major issue that would force me to switch back.

I also wanted to be able to mix and match - i.e., run Wayland on a few machines, stick to X11 on a few others, but (and that's the tricky part) avoid duplicating all the configuration, customization, etc.

The key for the "mix and match" part was to use [Sway].


## Sway

I use i3 and I really like its workflow. In particular, when *presenting* at meetups, conferences, or during training sessions, I like to have something like this:

- slides on workspace 1
- terminal on workspace 2
- browser on workspace 3
- local terminal on workspace 4
- public chat and messages on workspace 5

Workspaces 1 to 5 are assigned to my external video out (when presenting in person) or to the monitor that is shared with the public (when presenting online). Workspaces 6 to 10 contain "private stuff" that doesn't get shown to the audience, and these workspaces are typically assigned to a different monitor when that makes sense.

I've had this layout since 2015 (I think?) and it's been extremely useful and valuable: when I press Meta-1, Meta-2, etc., I know *exactly* what will show up on the screen that the audience sees.

I had tried a few times to achieve something similar with Gnome or KDE, but didn't succeed. Furthermore, on my older machine, Gnome and KDE feel very slow and sluggish, while i3 feels very snappy and reactive.

(Fun fact: at some point, the clock speed of one of my laptops was stuck to 200 MHz, and at first, I thought it was a Windows-specific issue, because Linux still felt "mostly okay" - because i3 is very lightweight and doesn't have any fancy visual effects slowing you down.)

With that in mind, it's no surprise that I wanted to use Sway on Wayland. Quoting Sway's home page:

> [Sway] is "a drop-in replacement for the i3 window manager" ...
> It works with your existing i3 configuration and supports most of i3's features ...

I found that indeed, I could switch from i3 to Sway (and back!) without changing my i3 configuration. This means that I can use the same configuration file on X11 and Wayland.

Of course, I had to adjust a few things.


## Things that needed tweaking

There are a number of things that are specific to X11 or Xorg, and that you need to change when moving to Wayland.

There is an excellent web page, [Are we Wayland yet?][awwy], that gives an amazing and extensive list of substitute programs. 90% of the time, when one of my particular tools or hacks didn't work anymore with Wayland, I was able to find a solution there.

To configure monitors on Xorg, I was using `arandr` (for one-shot configuration, for instance for a live presentation with a projector) and `autorandr` (to persist configurations). With Wayland, I'm now using `wdisplays` (for one-shot) or `kanshi` (for persistence).

To input emojis, I was using [splatmoji] (check my [splatmoji fork] that has an updated emoji set) on Xorg, and switched to [wofi-emoji] on Wayland.

I updated many helper scripts to add Wayland detection, and use the correct program depending on the environment. For instance, the script that I use to take a screenshot of a region of the screen looks like this:

```bash
#!/bin/sh
if [ "$WAYLAND_DISPLAY" ]; then
  slurp | grim -g- -t png - | wl-copy -t image/png
elif [ "$DISPLAY" ]; then
  scrot --silent --select --exec 'xclip -selection clipboard -t image/png -i $f'
else
  echo "Neither WAYLAND_DISPLAY nor DISPLAY was set. Can't copy a region from the screen."
  exit 1
fi
```

One particular item was my screen sharing configuration. The general idea is to have a 1080p virtual monitor that is dedicated to screen sharing. When doing a video call, I can share that virtual monitor; and when I deliver a live stream, I set up OBS to capture that virtual monitor. Then if I want to show an app, I just have to move its window to that virtual monitor.

With Xorg, it is possible to [use xrandr to split a physical monitor into multiple virtual monitors][xrandr-set-monitor]. I was splitting one of my 4K monitors that way (with [this script][sstk-xorg]).

This doesn't work anymore with Wayland. I tried a few different things, and eventually settled for a virtual monitor too; but the key difference is that the virtual monitor in Wayland is completely virtual and off-screen, which means that you don't see it at all. To be able to see what's happening on that screen, I've used [wl-mirror] (which is unfortunately not very reliable) or an OBS preview projector (which worked fine for me). You can see the script that I'm using to create the virtual screen and assign workspaces to it [here][sstk-wayland].


## Switching back and forth

I don't use a Desktop Manager. When my machines boot, they boot to text mode, with the old-fashioned `login:` prompt. I log in, and then I either run `startx` (which starts Xorg and directly runs i3, because my `~/.xinitrc` file has a single line: `exec i3`) or `sway` (which starts Wayland).

This means I can even terminate the graphic session and switch to the other environment in a few seconds, without rebooting. (Of course, I need to restart my apps in that case.)


## So... Are we Wayland yet?

Long story short: yes, as long as you're staying away from NVIDIA.

When I started my migration, I was using machines `kater` and the brand new `twister`. They both have an Intel iGPU, and everything worked great. I used that setup for 3+ months. Then I came back to `bolshoy`, which has an NVIDIA dGPU. To run Sway with NVIDIA proprietary drivers, you need [a few hacks][sway-nvidia-hacks]. The Sway authors [make it extremely clear that they have no interest in supporting NVIDIA proprietary drivers][sway-nvidia-wiki]. If you wonder why, [there is a blog post explaining the reasons][sway-nvidia-sucks]. TL,DR: every other GPU vendor supports KMS, DRM, and GBM (APIs used by most Wayland compositors) in their open source drivers; NVIDIA doesn't and tries to push alternative options (like EGLStreams) and the Linux graphics development community [isn't interested][eglstreams] (because the alternative options are NVIDIA-specific and tied to NVIDIA proprietary drivers and architecture; and NVIDIA claims that their approach is better, but there doesn't seem to be a consensus on that matter).

So, for about a month, I ran Sway with NVIDIA proprietary drivers anyway, understanding that it may or may not work. Well, it *kind of mostly worked*, but with numerous glitches. Sometimes, an app would not redraw properly or its display would be corrupted. Some pop-ups would consistently be totally unreadable - for instance, file selection pop-ups in some apps.

I decided to switch to the Intel iGPU on `bolshoy`, configuring Sway to use only the Intel iGPU and ignore the NVIDIA dGPU. Unfortunately, that didn't fully work either. As long as I was only using the Intel iGPU, things were fine (the display issues were gone); but when the NVIDIA dGPU was also in use (for video encoding) I was experiencing frequent freezes and even a few crashes requiring a hard reboot. Unfortunately, I still needed the NVIDIA dGPU, because the Intel iGPU in the 9600K isn't powerful enough to encode the ~150 fps that I needed for my 5 simultaneous video streams. (Note, however, that it works perfectly with the more recent 13600K in machine `twister`.) Additionally, the iGPU in the 9600K can't drive two 4K monitors at 60 Hz. (The DP output can do 4K@60Hz, but the HDMI output can only do 4K@30Hz or 1440p@60Hz.)

Eventually, I had to switch back to Xorg on `bolshoy`. Fortunately, everything worked fine - and I was glad that I had decided to follow this very prudent route of keeping 100% compatibility between Xorg and Wayland. Ultimately I might replace the NVIDIA dGPU with an Intel ARC or AMD card, but these are currently not very good with machine learning workloads.


## What CPU and GPU do I have again?

If you're usually not very concerned with the hardware that you're using, but find yourself curious about the kind of CPU or GPU that is in your machine, you can use the following commands:

```bash
$ lspci | grep -e VGA -e Display
00:02.0 Display controller: Intel Corporation CoffeeLake-S GT2 [UHD Graphics 630] (rev 02)
07:00.0 VGA compatible controller: NVIDIA Corporation TU116 [GeForce GTX 1660] (rev a1)

$ grep -m1 ^model.name /proc/cpuinfo
model name      : Intel(R) Core(TM) i5-9600K CPU @ 3.70GHz
```

```bash
$ lspci | grep -e VGA -e Display
c1:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1 (rev c4)

$ grep -m1 ^model.name /proc/cpuinfo
model name      : AMD Ryzen 7 7840U w/ Radeon  780M Graphics
```

Finally, to check whether you are already using Wayland or not, check these environment variables:

```bash
$ env | grep DISPLAY
DISPLAY=:0
WAYLAND_DISPLAY=wayland-1
```

`DISPLAY` will be present in both X11 and Wayland. `WAYLAND_DISPLAY` will be present only with Wayland.


## Final words

I'm sticking to Wayland on all my other machines. Given that Xorg maintainers themselves say that using Xorg ["to drive your display hardware and multiplex your input devices is choosing to make your life worse"][xorg-is-dead], it's reasonable to look for other options. I prefer to switch now, rather than in a few years, e.g. when Xorg won't run on my new machine.


[Arch Linux]: https://archlinux.org/
[awwy]: https://arewewaylandyet.com/
[eglstreams]: https://lists.freedesktop.org/archives/mesa-dev/2015-April/081155.html
[Factorio]: https://www.factorio.com/
[FMRACV]: https://github.com/jpetazzo/fmracv/
[i3]: https://i3wm.org/
[Nouveau]: https://nouveau.freedesktop.org/
[splatmoji]: https://github.com/cspeterson/splatmoji
[splatmoji fork]: https://github.com/jpetazzo/splatmoji
[sstk-wayland]: https://github.com/jpetazzo/sstk/blob/main/wlr-setup-for-obs.sh
[sstk-xorg]: https://github.com/jpetazzo/sstk/blob/main/xorg-split-screen-for-obs.sh
[Sway]: https://swaywm.org/
[sway-nvidia-hacks]: https://github.com/crispyricepc/sway-nvidia
[sway-nvidia-sucks]: https://drewdevault.com/2017/10/26/Fuck-you-nvidia.html
[sway-nvidia-wiki]: https://github.com/swaywm/sway/wiki#nvidia-users
[training]: https://container.training/
[Wayland]: https://wayland.freedesktop.org/
[Whisper]: https://github.com/openai/whisper
[wl-mirror]: https://github.com/Ferdi265/wl-mirror
[wofi-emoji]: https://github.com/Zeioth/wofi-emoji
[xorg-is-dead]: https://ajaxnwnk.blogspot.com/2020/10/on-abandoning-x-server.html
[xrandr-set-monitor]: https://www.baeldung.com/linux/xrandr-split-display-virtual-screen
