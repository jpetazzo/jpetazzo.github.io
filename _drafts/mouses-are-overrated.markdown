---
layout: post
title:  "Mouses Are Overrated"
tags: desktop
---

A question comes back haunting me every now and then: how is it to work
on a computer without a mouse? Forget about touchpads, trackballs, etc.:
we're talking about *keyboard-only* here. Recently, I decided to try it.

<!--more--> 

Interestingly, I was fine. After a few days of adaptation, I actually felt
more productive than before. Of course, some tasks were more difficult, or
even impossible; but with one exception, none of those tasks were related
to my work. Therefore, we can jump to hasty conclusions: **getting rid
of your mouse will make you more productive!**

Keep in mind that my job is part developer, part ops, part evangelist;
I don't do anything related to UX or graphics.


## Getting rid of the mouse

If you tell your brain "do not use the mouse", it probably will anyway.
So to make sure that I wouldn't cheat, I disabled my pointer altogether.
If you are on a Linux system, you can use `xinput` for that.

I listed my input devices:

```bash
$ xinput list
⎡ Virtual core pointer                    	id=2	[master pointer  (3)]
⎜   ↳ Virtual core XTEST pointer              	id=4	[slave  pointer  (2)]
⎜   ↳ Logitech Unifying Device. Wireless PID:101a	id=14	[slave  pointer  (2)]
⎜   ↳ DualPoint Stick                         	id=16	[slave  pointer  (2)]
⎜   ↳ AlpsPS/2 ALPS DualPoint TouchPad        	id=17	[slave  pointer  (2)]
⎣ Virtual core keyboard                   	id=3	[master keyboard (2)]
    ↳ Virtual core XTEST keyboard             	id=5	[slave  keyboard (3)]
    ↳ Power Button                            	id=6	[slave  keyboard (3)]
    ↳ Video Bus                               	id=7	[slave  keyboard (3)]
    ↳ Video Bus                               	id=8	[slave  keyboard (3)]
    ↳ Power Button                            	id=9	[slave  keyboard (3)]
    ↳ Sleep Button                            	id=10	[slave  keyboard (3)]
    ↳ Laptop_Integrated_Webcam_FHD            	id=13	[slave  keyboard (3)]
    ↳ AT Translated Set 2 keyboard            	id=15	[slave  keyboard (3)]
    ↳ Dell WMI hotkeys                        	id=18	[slave  keyboard (3)]
```

Then I disabled the TouchPad (I never use the Stick, so I knew that I would
not not use it inconsciously):

```bash
$ xinput float 17
$ xinput list
⎡ Virtual core pointer                    	id=2	[master pointer  (3)]
⎜   ↳ Virtual core XTEST pointer              	id=4	[slave  pointer  (2)]
⎜   ↳ Logitech Unifying Device. Wireless PID:101a	id=14	[slave  pointer  (2)]
⎜   ↳ DualPoint Stick                         	id=16	[slave  pointer  (2)]
⎣ Virtual core keyboard                   	id=3	[master keyboard (2)]
    ↳ Virtual core XTEST keyboard             	id=5	[slave  keyboard (3)]
    ↳ Power Button                            	id=6	[slave  keyboard (3)]
    ↳ Video Bus                               	id=7	[slave  keyboard (3)]
    ↳ Video Bus                               	id=8	[slave  keyboard (3)]
    ↳ Power Button                            	id=9	[slave  keyboard (3)]
    ↳ Sleep Button                            	id=10	[slave  keyboard (3)]
    ↳ Laptop_Integrated_Webcam_FHD            	id=13	[slave  keyboard (3)]
    ↳ AT Translated Set 2 keyboard            	id=15	[slave  keyboard (3)]
    ↳ Dell WMI hotkeys                        	id=18	[slave  keyboard (3)]
∼ AlpsPS/2 ALPS DualPoint TouchPad        	id=17	[floating slave]
```

The TouchPad is not "floating"; its events won't be propagated to the X11
core pointer.

I kept the other pointing devices as backups. I'm really not good with the
Stick, so I knew that I would rather struggle with the keyboard, than even
thinking about using the Stick.

Anyway, if I need to re-attach the pointer, all I have to do is
`input reattach 17 2`.


## Windows