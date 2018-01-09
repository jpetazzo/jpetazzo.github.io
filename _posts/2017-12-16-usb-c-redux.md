---
layout: post
title: USB-C redux
---

A few months ago, I started using a 2017 12" Macbook Air.
This machine has only two ports: an audio jack, and *one*
USB-C port. That USB-C port is the only thing you have
to plug external storage and monitors, network connectivity,
and of course, a power supply. I had to do some research
to understand how USB-C works, and find the perfect adapters
(at least, the perfect adapters for what *I* do).

Here is a summary!


## TL,DR

If you have a machine like mine, with only one USB-C port,
*and* it without Thunderbolt support, this is what I recommend:

- at home: [Plugable USB-C docking station](https://www.amazon.com/Plugable-Charging-Delivery-Specific-Thunderbolt/dp/B01FKTZLBS/)
- on the go: [TNP USB-C multi adapter](https://www.amazon.com/TNP-Displayport-Ethernet-Converter-Connector/dp/B07474QTKP/)

**The docking station is great.** Its only downside (for me!)
is that it doesn't have a DisplayPort output; but you can get 4K
on the HDMI port (if your monitor supports it; some older monitors
support higher resolutions only on their DP inputs). This means that
you can't use DisplayPort MST to cascade multiple screens. However,
the dock has two extra *DsplayLink* ports (one DVI, one HDMI) that
might or might not be helpful. (I'll cover DisplayLink briefly
later.)

**The adapter is great too.** Its only downside (again: for me!)
is that it uses a lot of power, and that's why I ended up
also getting a dock.
The charger that comes with the MacBook Air
delivers 40W. Once I insert the adapter between the charger
and the MacBook, the latter reports that it is connected
to a 13W power supply. This means that the battery will charge
very slowly, or even drain slowly, if you are doing CPU intensive
tasks (and that machine has a very weak CPU, so sometimes
"having too many tabs open" can be CPU intensive!).
Also, that means that the adapter dissipates a lot
of heat. Finally, if you don't need that plethora of connectors,
there are smaller adapters that you might like more.

Both worked out of the box without installing drivers
(but I had other USB adapters in the past, so perhaps at some
point I installed a driver that took care of business).

If your machine supports Thunderbolt 3 (like the Macbook Pros,
which also have more than one USB-C port), you can also look
at these options:

- this [Thunderbolt 3 Docking Station](https://www.amazon.com/gp/product/B073JDZGKK/)
  (thanks [Bryan](https://twitter.com/bryanl/status/949005817763844102)
  for the recommendation!)
- this [Satechi Hub Adapter](https://www.amazon.com/gp/product/B06XS5CWDG/)
  (thanks [Hunter](https://twitter.com/twobree/status/949002776612352005)
  for the recommendation!)

Finally, I'm aware that these adapters are not cheap.
This is not an extorsionist move from the adapter lobby:
as we will see when we dive into the details of USB-C,
some features are simple, others require more complex
circuitry.

If you're on a budget, you may get similar functionalities
by getting multiple cheaper adapters and switching between
them when necessary. Then again, if you're on a budget,
I would humbly suggest to stay away from Apple hardware.


## What I wish I had been told about USB-C

There is a lot of information out there, and it's not
easy to find palatable technical information, between
marketing announcement, outdated press releases, and
arcane spec sheets. This is my attempt at explaining
USB-C in terms that are "just enough technical."

According to [Wikipedia](https://en.wikipedia.org/wiki/USB-C):

*USB-C, technically known as USB Type-C, is a 24-pin USB connector system.*

(In this whole post, I am using "USB-C" for "USB Type-C".)

So, USB-C is a *connector*. It's not a protocol! The protocol
would be e.g. USB 2, or USB 3, or something else.

This connector has the ability to carry
many different electric signals, including:

- USB 1, USB 2 (for compatibility with existing devices)
- USB 3 (the kind you've probably seen on [the blue connectors with extra pins](https://en.wikipedia.org/wiki/USB_3.0#Connectors))
- power (to charge e.g. a phone, but also more power-hungry
  devices like laptops, up to 100W as of late 2017)
- DisplayPort
- Thunderbolt
- HDMI
- a few other fancy things

All these electric signals can be present on a USB-C
connector (but maybe not all at the same time!), and
as far as I understand, none of them is mandatory.

So when you see a USB-C connector, it could be:

- just for power (that's the case for the connector
  on a charger for a phone or computer)
- just for USB (that's the case for the basic
  [USB Type A / Type C adapters](https://www.amazon.com/AUKEY-Adapter-Samsung-MacBook-Google/dp/B01AUKU1OO/))
- just for DisplayPort, or Thunderbolt, or HDMI
  (that's the case for the basic video adapters sold by Apple)

But it could also be (almost) all these things at the
same time!


## Alternate modes

The 12" Macbook Air has only one USB-C connector,
but that connector can support many different electric
signals simultaneously.

This is a feature in the USB-C spec, called "alternate modes"
or "alt modes" in short.
That's how signals like DisplayPort, Thunderbolt,
or HDMI are supported. When an "alt mode" is enabled,
some "high speed lanes" (electric wires normally used for USB 3)
are hijacked to transport the corresponding alt mode instead.

Carrying DisplayPort, Thunderbolt, or HDMI signals, requires
enabling the corresponding alt mode. It has to be supported
on both sides of the cable (i.e. by the host and the device).
You can't connect a Thunderbolt device over USB-C to an
host that doesn't support Thunderbolt (more on that later).

If that helps, you can imagine that inside this computer,
we actually have a bunch of sockets for power, USB 2, USB 3,
DisplayPort, and HDMI; and all these sockets are connected
to that single USB-C connector. Then you can put an
(expensive) adapter or dock station, to get all these sockets
back.

I'm very bad with drawing, but I found a nice diagram
in [this document](http://www.ti.com/lit/wp/slly021/slly021.pdf):

![Host and device and USB-C between them](/assets/usb-c-host-and-device.png)

The document has other schematics and explanations that
you might like if you want to know more.


## The 12" Macbook Air doesn't have Thunderbolt

Just because a machine has USB-C, doesn't mean that
the machine supports all these protocols and signals.
For instance, the 12" Macbook Air *does not*
have Thunderbolt. The 13" and 15" Macbook Pros *do have*
Thunderbolt. This means that if you plug an Apple Thunderbolt
display, using Apple's adapter, on a Macbook Pro, it
will work; but if you plug the same display, with the
same adapter, on a 12" Macbook Air, no dice.

To make things even more frustrating and confusing:
the Thunderbolt connector is physically identical to
a miniDP connector. Any other (non-Thunderbolt)
display with a miniDP
connector *will* work on any Macbook with the correct
USB-C adapter (because it will use the DisplayPort
protocol).

Thanks Apple, I guess.


## Connecting screens over USB-C, the easy way

If we want to connect external monitors with USB-C,
we have plenty of options.

Assuming that the external monitor has an HDMI (or
DisplayPort) connector, the most straightforward option
is to use an adapter leveraging "HDMI alt mode"
or "DisplayPort alt mode". If you have multiple
USB-C ports, these adapters are a good option, because
they are cheap, since the circuitry in them
is pretty basic. Of course, our source
(i.e. your laptop) needs to support HDMI alt mode
or DisplayPort alt mode (the latter is also known as
VESA alt mode, by the way).

Most laptops with USB-C ports will support these modes,
but I don't know if this is true for *all* laptops.
(E.g. I don't know about Chromebooks and other cheap ones.)

Phones and tablets are a totally different story! They
may or may not support alt modes. I don't expect any
phone to support HDMI or DisplayPort alt modes.
However, there is "MHL alt mode"
which seems to be designed to carry video signals from
mobile devices. I don't have any device supporting
that so I don't know if you can use the same adapters or
need different ones.

And then, there is *DisplayLink.*


## Connecting screens with DisplayLink

DisplayLink is basically "video stream over USB."

A DisplayLink adapter might look physically
exactly like an alt mode adapter; except that it
will work very differently. When you connect a
DisplayLink adapter, instead of negotiating alt
mode to allocate a few wires to HDMI signals,
it will present itself
as a regular USB device—i.e. one that shows up
in `lsusb`. The driver for this USB
device will behave like a graphics adapter. When
you display something on this graphics adapter,
the display is encoded, sent over the USB protocol,
decoded by the DisplayLink adapter, and shown on
the connected physical screen.

These extra steps mean that a DisplayLink
adapter will use extra CPU cycles (because of the
video encoding), and depending on your setup,
this can add a tiny bit (or a good bit) of extra latency.
Various sources recommend to NOT use DisplayLink
for gaming.

Superficial research showed that there might be
DisplayLink drivers available for Linux, but I didn't try.

So far, it sounds like DisplayLink has a bunch of
inconvenients: it needs a custom driver, eats CPU
cycles, adds latency ... But it has two advantages:
you can plug as many as you want on your machine
(since they're just normal USB devices), and I saw
references to Android drivers, meaning that it might
work on some tablets.

This is why you can end up with an adapter that works
out of the box, without drivers, on a machine; and an
adapter that works almost out of the box (if, say,
the driver is loaded automatically) on a tablet;
but the adapters are not interchangeable (they won't
work with the other device) because they're fundamentally
different.

*There is a lot of "maybe" in that section, because
I didn't take the time to try DisplayLink so far.
Sorry!*


## One adapter to rule them all

Alright, now that we are armed with all that knowledge,
let's find the best adapter EVER.

Everyone's needs are different, but I wanted to find
a way to have the following connectors on my Mac:

- gigabit Ethernet
- a few USB ports
- VGA (it's getting very rare that I need that one,
  but who knows)
- HDMI
- power

The latter might seem weird, but many adapters (including
some from Apple) don't pass power to
the computer; and remember: that 12" MacBook Air has only
one connector. You then end up with a difficult choice:
do I want to connect my external monitor, or do I want to
charge my battery?

I also wanted to be able to connect everything at
the same time.

"Whoa, that Jérôme guy for sure is picky!"

As it happens, when I deliver a full day workshop, I need:

- wired connectivity
- at least one USB port for my remote clicker
- VGA or HDMI for the projector
- power (full day workshop, remember)

I also wanted to get an extra USB-C port on the adapter,
because I wanted to be able to buy USB-C devices (e.g.
memory sticks, security tokens...) without
having to choose between the device and everything else.

It turns out that I had to drop that last requirement,
as (in August 2017) I couldn't find any adapter
that would connect to a single USB-C port and then provide
more USB-C ports (in addition to my other requirements).

I got [this adapter](https://www.amazon.com/TNP-Displayport-Ethernet-Converter-Connector/dp/B07474QTKP/). The reviews might not be stellar, but it
works great for me. It also has SD and miniSD card
readers (which I use once every blue moon to re-image
a Raspberry Pi), and audio output (because why not).
In addition to VGA and HDMI, it has a miniDP connector as well.

The adapter can also be used as a USB charger: if
it is connected to the AC adapter, but not to the computer,
it will still deliver power to the USB A ports.

Likewise if it is connected to the computer, but not
to the AC adapter: it can charge your phone and other
devices from the battery of your laptop.

Note, however, that when you plug/unplug the AC
adapter, it seems to "reset" the adapter (as if you had
disconnected and reconnected all the peripherals).
Keep that in mind if you have a disk connected,
or if you're performing live music with a USB MIDI
controller.


## One dock to rule them all

I do some video editing sometimes (as well as some other
CPU intensive tasks), and my adapter then has a "small"
problem: the battery will charge very slowly, or even
discharge if the CPU stays running at high speeds for
continued periods of time. So eventually, I also got
a dock. It's not a "dock" like the docks I was used to
(where you physically lock the computer to a base).

There are many docks out there, with varying options.
I wanted something just like my adapter, but with
full power delivery to the host, and with at least one
extra USB-C port, so that I wouldn't be constantly
plugging/unplugging stuff if I decided to buy some
USB-C peripheral.

I picked [that dock](https://www.amazon.com/Plugable-Charging-Delivery-Specific-Thunderbolt/dp/B01FKTZLBS/).
It might seem expensive, but the other ones that did fit
my requirements were sometimes more than $300 (!).
There were also a bunch of docks boasting Thunderbolt support,
and I didn't know if that meant "and also, it supports Thunderbolt!"
or "and by the way, it *requires* Thunderbolt!" — the latter would
have been a showstopper.

The dock also has mic and headphone connectors, which
can be super convenient. I had a headset connected to these for
a while. I never really understood how macOS picked which
default output to use, but most modern conferencing software
has easily accessible settings to switch audio devices to
make up for that.

Having a dock also means much less plugging/unplugging:
the dock can stay at home, and all my peripherals can stay
connected to it, while the adapter stays in my backpack
for when I'm on the go.

A couple of observations:

- hindsight 20/20, it might have been better to get a dock
  with DisplayPort (to support cascading display with MST),
  but the HDMI output on the dock can carry 4K, so I'm fine with it;
- initially, I wanted a dock that got power from USB-C
  (to simplify the different types of cables I had around)
  but I couldn't find any. Perhaps because it's way cheaper to
  tack a classic AC adapter, rather than a fancy USB-C power
  supply and the corresponding circuitry in the dock.


## Wrapping it up

After spending a bunch of time reading on USB-C, trying to understand
what would work, what wouldn't, etc., I think it is pretty fantastic
to be able to use a single connector for so many things.
The transfer speeds are orders of magnitude faster than USB 2:
with Thunderbolt 3 over a USB-C connector, you can supposedly
get 40 Gb/s. You can even connect *external GPUs* through USB-C,
because Thunderbolt can carry PCI Express lanes!
(Don't hold your breath, though: this is still pretty early stage.)

However, since all hosts (machines) and devices don't
support all these modes, it means that debugging problems
gets really complicated, especially without knowing of
the underlying fundamentals of USB-C, alt modes, etc.

For instance, if I plug my dock or my adapter to an Android
phone with an USB-C connector, *nothing* happens. Obviously,
I didn't expect my phone to suddenly drive my 4K monitor,
connect over my gigE interface, and mount my external disks
connected to the dock. But the USB-C spec includes a lot of
signaling and negotiation to let each side identify itself
and its capabilities. It would be fantastic if the devices
could use that and report it adequately: it would make
for a much better user experience. Hopefully that will
evolve in the future.

If there is an adapter or dock that you particularly like,
feel free to drop me a note, I'll add it here for others!
