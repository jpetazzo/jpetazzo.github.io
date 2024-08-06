---
layout: post
title: "Installing Archlinux with LUKS, SecureBoot, TPM"
---

Once in a while, I need to install Archlinux on a new machine. This is the procedure that I follow. It has been recently updated to include root device encryption using LUKS, with the encryption keys stored in the machine's TPM, and uses SecureBoot so that the device can be unlocked without typing a passphrase, while retaining a good(ish) security level.


## A tiny bit of context

I usually don't need to install or reinstall Linux very often (I don't deploy lots of physical machines). It's mostly on new laptops or desktop machines, or when a disk fails. Since I don't do it very often, it helps to have some notes to remember the different steps, command-line flags, etc.

I've considered fully automating the process (e.g. with custom ISO/USB images or PXE boot) but since each machine and install are slightly different, I'm fine with just a detailed procedure.

Recently, my Dell XPS 13 main board failed. On that model, the NVMe disk is soldered to the main board. When Dell replaces the main board, you end up with a blank system and need to reinstall. Shortly after getting the main board replaced, another failure happened (the WiFi card disappeared - no longer listed in `lspci` - and one of the USB ports completely died). It had to be replaced again (one more reinstall). And then the replacement board had *another* problem: the the CPU clock wouldn't go above 200 MHz. That last issue was a huge pain in the neck to address, because the machine's diagnostics would still pass, so Dell initially refused to change the main board. They insisted on updating drivers, reinstalling Windows, etc. and it took almost 10 days of constant back-and-forth with them to finally get them to replace the main board. (As soon as the main board was replaced, the system was fine.)

Since I had to reinstall that system multiple times in the span of a few weeks, I decided to clean up my notes, improve the process a bit (e.g. automate partition creation, store LUKS keys in TPM, enable SecureBoot) and turn that into a blog post in case it's useful to others. The commands are presented in such a way that if you're connecting to the machine over SSH, you can copy-paste 90% of them without having to tweak too many things, and it then takes about 10 minutes from end-to-end to get everything up and running.

Disclaimer: there is nothing special or original about this install process. Most of the information has been gleaned from the Archlinux wiki, in particular the [Installation Guide][archinstallguide]. If you're interested by the SecureBoot + TPM2 + LUKS bits, the following resources have been very helpful:
- [Rogue AI blog post][rogueai]
- [Morten Linderud blog post][mkinitcpio]
- [Lennart Poettering blog post][unlockluks]



## Preparation

Make sure that the machine has free (non-partitioned) disk space. A totally blank disk is fine. If you dual boot Windows, you can shrink the Windows partition from Windows. (That's what I do because my laptop won't install Windows with the normal Windows ISO images; I have to build a recovery media from another machine, and the recovery process completely wipes the partition table and destroys everything that was on the disk anyway. Ain't that just lovely!)

If you want to do the (optional) SecureBoot part, enter the BIOS and look for the SecureBoot options. We will need to enroll our own keys, so switch to "Setup Mode" (it's called "Audit Mode" on my Dell BIOS).

Get an Archlinux ISO/USB image and copy it to a USB stick. Boot it. Get to the shell.


## Connecting to internet

You can skip this step if you just want to mess around with partitions, chroot into an existing system, etc.; but to install Archlinux, we will need internet access eventually (to download packages).

Also, personally, I prefer to do the install from another machine (so that I can copy-paste commands and error messages if necessary) so I start the SSH server, add my keys to the root account, and log in from the other machine to continue from there.

```
ESSID="Your WiFi Network Name Here"
iwctl station wlan0 connect $ESSID
```

Note: sometimes, it seems necessary to run `iwctl station wlan0 scan` before trying to connect. I don't know why.


## Partitioning disks

The general idea is that we want:
- a large-ish (100+ GB) partition for the Linux system
- a swap partition (not strictly mandatory)
- a large enough (1+ GB) boot partition

Ideally, the boot partition will be an "ESP" or "EFI System Partition". This is a special partition type, typically formatted using the VFAT filesytem, so that it's readable by the machine's UEFI firmware.

The boot partition will hold the boot loader files as well as our kernels, ramdisks, microcode files. A typical kernel + ramdisk is around 30 MB on my machines. A rescue kernel + ramdisk is around 150 MB. Multiply these figures by two if you're keeping the previous kernel around as a fallback, or if you're experimenting with different kernels. If you're booting multiple OSes, they will share the same boot partition, so you might want to account for that too. Personally I like to have 1 GB here to be on the safe side.

If you already have Windows installed on the machine, it is likely that you already have an EFI System Partition, and that it is fairly small (e.g. 100 MB). The Windows boot process is extremely brittle, so resizing or moving that ESP might render the Windows system unbootable. Since the Windows boot process doesn't produce useful error messages, it is fairly difficult to figure out what's confusing it. The recommended approach in that case is to create a separate "Linux extended boot" partition. The (relatively small) Linux boot loader will be installed on the ESP (alongside the Windows and other boot loaders), and the (relatively big) Linux kernels and initrds and other files will go to the extended boot partition.

When there is just an ESP, it is typically mounted on `/boot`.

When there is both an ESP and an extended boot partition, the ESP is typically mounted on `/efi` and the extended boot partition on `/boot`.


### Plan 1: manual partitioning

- find disks with `lsblk`
- use `cfdisk` to partition disk
- if there is no partition of type "EFI System":
  - it will be mounted on /boot
  - it will be the "ESP" (EFI System Partition)
- if there is an "EFI System" partition of 1G or more:
  - nothing to do!
  - we will mount it on /boot
- if there is an "EFI System" partition of less than 1G:
  - create a 1G partition, type "Linux extended boot"
  - it will be mounted on /boot
  - the "EFI System" partition will be mounted on /efi
- create the other partitions:
  - e.g. 300G "Linux filesystem" for /
  - e.g. 32G "Linux swap"
- recommended: set the type of the partitions accordingly
  (i.e. "Linux swap" for the swap partition, and "Linux root (x86-64)"
  for the root partition - if you're on amd64)
- "recent" (2022ish?) versions of systemd boot hooks will
  be able to recognize these partitions, meaning that it won't
  be necessary to put them in /etc/fstab, nor to pass the root device
  to the kernel command line


### Plan 2: semi-automatic partitioning

Find disks with `lsblk`. Here is some example output:


```
NAME        MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
loop0         7:0    0 757.8M  1 loop  /run/archiso/airootfs
sda           8:0    1  14.3G  0 disk
├─sda1        8:1    1   868M  0 part
└─sda2        8:2    1    15M  0 part
nvme0n1     259:0    0 953.9G  0 disk
├─nvme0n1p1 259:8    0   100M  0 part
├─nvme0n1p2 259:9    0    16M  0 part
├─nvme0n1p3 259:10   0   300G  0 part
└─nvme0n1p4 259:11   0   598M  0 part
```

`/dev/sda` is the USB stick with the Archlinux installer.

`/dev/nvme0n1` is the disk where we want to install Archlinux. It's not directly obvious from the output of the `lsblk` command, but there is a bit more than 600G available (not partitioned) on that disk.

``` 
DISK=/dev/nvme0n1

# Show the current partition table
sgdisk $DISK --print

# Since we already have an ESP, and it's small, let's create an XBOOTLDR partition
sgdisk $DISK --new=0:0:+1G --change-name=0:boot --typecode=0:ea00

# On a completely blank disk, or a disk with no ESP, we could create an ESP partition
#sgdisk $DISK --new=0:0:+1G --change-name=0:boot --typecode=0:ef00

# Create root partition and swap partition
sgdisk $DISK --new=0:0:+500G --change-name=0:archlinux --typecode=0:8304
sgdisk $DISK --new=0:0:+32G --change-name=0:swap --typecode=0:8200

# Check that everything is fine
sgdisk $DISK --print
```

Here is what the last `sgdisk` command shows us on my system:
```
...
Number  Start (sector)    End (sector)  Size       Code  Name
   1            2048          206847   100.0 MiB   EF00  EFI system partition
   2          206848          239615   16.0 MiB    0C01  Microsoft reserved ...
   3          239616       629385215   300.0 GiB   0700  Basic data partition
   4      1999183872      2000408575   598.0 MiB   2700  Basic data partition
   5       629385216       631482367   1024.0 MiB  EA00  boot
   6       631482368      1680058367   500.0 GiB   8304  archlinux
   7      1680058368      1747167231   32.0 GiB    8200  swap
```

Note: naming the partitions isn't strictly necessary, but it makes it possible to reference them at `/dev/disk/by-partlabel/`, which is pretty convenient in my humble opinion.

Alright, let's set this env var for convenience:

```
ROOTDEV=/dev/disk/by-partlabel/archlinux
```

## Encrypting the Linux partition

Encrypting the Linux partition gives you some extra security if your machine's disk is no longer in your possession, for instance:

- if the machine (or its disk) gets stolen
- if you need to send back the machine or the disk for replacement or repair (and can't wipe the disk before)

On modern machines, the performance and CPU overhead of disk encryption is negligible.

On the other hand, each time you boot your machine, you will need to provide the encryption key. It will not be possible to boot the machine without the key. Typically, the key is secured by a password (that has to be provided at each boot). This can be problematic for machines that need to be able to boot unattended. In my case, I have machines at home that are usually off, and I turn them on with wake-on-lan when I'm away. Since I'm not physically at the machine, I cannot type a password; and at this point, the machine hasn't booted, so it's not connected to internet or VPN etc. We'll see later how to store the key in the machine's TPM to solve that.

Note: if you don't want to encrypt the Linux partition, just skip this step!

The commands below will ask you a password. You can put a dummy password at this point (e.g. "1234"). LUKS doesn't directly derive the encryption key from the password. Instead, it will generate a secure key, then store the key in a "key slot", itself encrypted with the password. This means that later, we will be able to change that dummy password without having to re-encrypt the whole disk. There are multiple key slots, which means that we can have multiple passwords, as well as recovery keys, keys stored in the TPM or other hardware modules, and we can even completely remove the password if we use other key slots.

```
cryptsetup luksFormat --type luks2 $ROOTDEV
cryptsetup luksOpen $ROOTDEV root
ROOTDEV=/dev/mapper/root
```


## Making filesystems and installing Linux

This is fairly straightforward. This is mostly pulled from the [Archlinux installation guide][archinstallguide].

```
mkswap /dev/disk/by-partlabel/swap
swapon /dev/disk/by-partlabel/swap
mkfs -t ext4 $ROOTDEV
mount --mkdir $ROOTDEV /mnt
mkfs -t vfat /dev/disk/by-partlabel/boot
mount --mkdir /dev/disk/by-partlabel/boot /mnt/boot

# If there is a separate ESP:
mount --mkdir /dev/disk/by-partlabel/EFI* /mnt/efi
```

This is not strictly necessary. The parallel downloads typically make it faster to download packages; and according to an MIT study, the `Color` will make your install 42% more fancy [[citation needed]].

```
sed -i "s/^#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
sed -i "s/^#Color/Color/" /etc/pacman.conf
```

Now I suggest to have a look at `/etc/pacman.d/mirrorlist`. It should have been automatically populated with the mirrors closest to your location; but if it hasn't, then you can run this:

```
reflector --save /etc/pacman.d/mirrorlist \
--protocol https --latest 5 --sort age
```

Now install the base system and a few extra packages:

```
pacstrap -K /mnt base linux linux-firmware linux-headers \
less sudo git base-devel networkmanager vim man-db man-pages openssh
```

Then drop into the newly installed system for some finishing touches:

```
arch-chroot /mnt

# Adjust and run the following command if your system will
# be in a given timezone (personally I keep it in UTC and just
# set the TZ environment variable in my profile, but you do you!)
# ln -sf /usr/share/zoneinfo/Region/City /etc/localtime

MYHOSTNAME=fancyhostnameoowee
MYUSERNAME=jp
ROOTPASSWORD=securerootpassword
USERPASSWORD=secureuserpassword

hwclock --systohc
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen

echo $MYHOSTNAME > /etc/hostname

# Optionally, set a root password
chpasswd <<< root:$ROOTPASSWORD

# Optionally, create a user (strongly recommended :))
useradd -m $MYUSERNAME
chpasswd <<< $MYUSERNAME:$USERPASSWORD
echo "$MYUSERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$MYUSERNAME

# Personally I like to enable these, but that's up to you
systemctl enable NetworkManager.service
systemctl enable sshd.service
```


## Setting up the bootloader

I use systemd-boot. Feel free to use something else, but you might have to adjust the SecureBoot part later (if you intended to use SecureBoot).

If you only have the "EFI System" partition:

```
bootctl install
```

If you have both "EFI System" and "Linux extended boot":

```
bootctl install --boot-path=/boot --esp-path=/efi
```

Personally I like to edit `$ESP/loader/loader.conf`:
```
console-mode auto
default @saved
timeout 10
```
(Replace `$ESP` with /boot or /efi depending on where your EFI System Partition is located.)

Note: `default @saved` means that instead of booting systematically to Linux or Windows or whatever, systemd-boot will boot to the "default entry". That "default entry" can be changed with `bootctl set-default` or in the boot menu itself (by selecting an entry and pressing `d`). Check the `systemd-boot` manpage for more funny keyboard shortcuts!

At this point, we're supposed to generate `/etc/fstab`, but we won't do it. Instead, we're going to use a "fancy" initrd, based on systemd, which will automatically detect our various partitions, using GPT partition types. That's why we had to set the partition types correctly earlier.

## Generating the initrd

If you don't want to use SecureBoot, you can generate an initrd, reboot, and call it a day. If you want to use SecureBoot, you can generate the initrd anyway and check that everything is fine before going on to the SecureBoot section. But you can also skip this section (and go straight to "Setting up SecureBoot") if you want.

To generate the initrd, we need to first edit `/etc/mkinitcpio.conf` and update the `HOOKS` line to use the fancy systemd initrd mentioned previously:

```
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)
```

- `systemd` is here for the partition detection
- `sd-encrypt` will detect LUKS partitions and unlock them (prompting us for the password if necessary)

We can now build the initrd:

```
mkinitcpio --allpresets
```

Then we configure [systemd-boot][systemdboot] to add a Linux entry:

```
cat >/boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
#initrd /amd-ucode.img
#initrd /intel-ucode.img
initrd /initramfs-linux.img
#options root=LABEL=xxx rootfstype=ext4
EOF
```

I've commented out the microcode files; feel free to install the relevant package for your CPU and uncomment the corresponding line.

I've also left a commented out `options` line just in case you don't want to use partition autodetection.

At that point, we can already reboot into the newly installed system if want.


## Setting up SecureBoot

Here is a really quick primer about SecureBoot and TPM, in case you wonder why we would bother with all that. Please note that I'm not a SecureBoot expert, and it's quite possible that I'm misusing some terminology here or even got a few things completely wrong. If you're an expert in these things, feel free to point out the mistakes so I can fix that part :)


### TPM and PCRs

Most modern PCs have a TPM (Trusted Platform Module). The TPM has various features, including:
- a secure random number generator (not used here but nifty anyways)
- the ability to store encryption keys securely
- the ability to verify that a system is "trusted", and only give access to the encryption keys if it is

"Trusted" here means that the entire boot chain has to be signed properly. This includes the boot loader and the kernel as well as the associated files (initrd, CPU microcode) and the kernel parameters.

"Signed properly" means signed by a key enrolled into the TPM. By default, the TPM has at least keys from Microsoft, meaning that it's fairly straightforward to boot Windows into SecureBoot mode. There might also be some Red Hat keys but I didn't look much into that.

The "trusted" aspect of the system isn't a binary thing (trusted / non-trusted). In fact, the TPM supports multiple PCRs (Platform Configuration Registers) that store hashes of various system components. For instance, on Linux, PCR11 will contain the hash of the kernel boot image (kernel, initrd, and associated options) and PCR12 will contain the hash of the kernel command line. These hashes are called "measurements". Keys can be bound to a specific set of PCR measurements, which means that the keys will be available only when the designated set of PCRs will match specific values. In other words, it is possible to set up the TPM so that a the key that unlocks our Linux partition is only available when booting a specific Linux kernel with a specific command line, and altering any of these (e.g. to put a good old `init=/bin/bash`) would cause the corresponding PCR hash value to change and therefore the TPM would refuse to unseal the key. 

You might wonder: "Hey, if I get anything wrong, could that make my system unbootable?" As far as I understand, if you change something that affects the PCR measurements (and the TPM refuses to unseal the key), or even if you disable SecureBoot altogether, you will still be able to boot your system; but you will need to provide your LUKS password or recovery key to unlock your root device. (I believe that this is why my friends who use Windows BitLocker complain about having to enter their BitLocker recovery key after some software or hardware upgrades, but I have zero direct experience with BitLocker myself.)

By the way: there are two versions of TPM, and if I understand correctly, they're very different. TPM2 is not just a superset of TPM1. We're going to use TPM2 here.


### SecureBoot with Linux

I'm a little bit unsure about the low-level implementation details here. I don't know if the boot loader is the one loading the boot files (kernel, initrd, microcode...), verifying their signatures, and reporting the PCR measurements to the TPM; or if the file loading actually goes through some UEFI function calls that take care of the verification and update the PCR. Either way, with systemd-boot, the recommended way seems to be to build a Unified Kernel Image (UKI). A UKI is an executable file that bundles together everything that is needed to boot the system (kernel, initrd, microcode, kernel command line) and can be loaded (and executed) directly by the UEFI. As it's a single file, it can also conveniently be signed, thus ensuring that when we validate the signature and execute it, nothing has been tampered with (nothing has been changed in the initrd or the kernel command line, for instance).

Long story short: we need to generate and sign UKIs.


### Enabling it all

Install the SecureBoot package:
```
pacman -S sbctl sbsigntools
```

check that "Setup Mode" is "Enabled":
```
sbctl status
```

If it's not, make sure that you didn't forget to set the BIOS to "Setup Mode" (or "Audit Mode" on my Dell BIOS). If you did, you'll need to reboot, do that, then come back to the installer. Boo!

Create your own signing keys:
```
sbctl create-keys
```

For reference, `sbctl` places generated keys in `/usr/share/secureboot`.

Sign the systemd bootloader:
```
sbctl sign -s \
  -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
  /usr/lib/systemd/boot/efi/systemd-bootx64.efi
```

Enroll your custom keys:
```
sbctl enroll-keys --microsoft
```

The `--microsoft` is useful only if you're going to dual boot to Windows. You can remove it otherwise.

If you get permission errors, you might have to `chattr -i` a couple of files, then try again.

Now we need to configure `mkinitcpio` so that it generates UKI in addition to "normal" initrds.

First, if you haven't done it already, edit `/etc/mkinitcpio.conf` and update the `HOOKS` line:
```
HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)
```

Then edit `/etc/mkinitcpio.d/linux.preset`, and uncomment the `default_uki` and `fallback_uki` lines. Change the paths there from `/efi` to `/boot`, since if we have a separate EFI System Partition, it will generally be too small anyway.

Note: if `/etc/mkinitcpio.d/linux.preset` doesn't exist, make sure that the `mkinitcpio` and `linux` packages are installed. Re-install them if necessary. (That happened to me once when I was tinkering around.)

Build the new initrd and our new Unified Kernel Images:
```
mkinitcpio --allpresets
```

We can now sign all these EFI binaries:
```
sbctl sign -s /boot/EFI/Linux/arch-linux.efi
sbctl sign -s /boot/EFI/Linux/arch-linux-fallback.efi
sbctl sign -s /efi/EFI/systemd/systemd-bootx64.efi
sbctl sign -s /efi/EFI/Boot/bootx64.efi
sbctl verify
```

The `-s` (or `--save`) flag means that `sbctl` will store that file's location in its database, so that we can re-sign everything later (e.g. after a kernel upgrade) with `sbctl sign-all`. (We won't have to do that ourselves; this is automatically done by `mkinitcpio` hooks.)

If you're dual booting and see errors about Microsoft stuff not being signed, don't worry, that's normal: `sbctl` only verifies with our keys here.

We can now reboot using the new EFI iamges.

At this point we'll still need to give our root volume password when booting, but the next step will be to use a key in the TPM instead.


## Enrolling a TPM key

```
# Install the TPM tools
pacman -S tpm2-tools

# Check the name of the kernel module for our TPM
systemd-cryptenroll --tpm2-device=list

# Generate a recovery key (not mandatory but strongly recommended)
systemd-cryptenroll --recovery-key /dev/gpt-auto-root-luks

# Generate a key in the TPM2 and add it to a key slot in the LUKS device
systemd-cryptenroll --tpm2-device=auto /dev/gpt-auto-root-luks --tpm2-pcrs=7

# This is the command to use later, to remove the (insecure) initial password
#systemd-cryptenroll /dev/gpt-auto-root-luks --wipe-slot=password
```

Note: `--tpm2-pcrs=7` means that the key will be available only with the current Secure Boot state. In other words, if Secure Boot is disabled, or if Secure Boot keys are altered, the key won't be available. This means that if you turn off Secure Boot to boot a rescue ISO, the key won't be available On the other hand, it doesn't measure the kernel and initrds, so if you upgrade your kernel, the key will still be available. Some folks might decide to but an even more restrictive set of PCRs here, but it will then require more work when upgrading kernels. Check the `systemd-cryptenroll(1)` manpage for some details.

Check if your TPM requires a kernel module:

```
lsmod | grep tpm
```

If your TPM requires a kernel module, edit `/etc/mkinitcpio.conf` one more time and edit the `MODULES` line to add the module used by your TPM (as identified above). For instance:

```
MODULES=(tpm_tis)
```

Run `mkinitcpio --allpresets` one more time, reboot, and this time you shouldn't have to enter a password to unlock the root volume!

<!--

That part doesn't quite work yet (couldn't get FIDO2 token to work at boot time; and this is hard to debug because systemd initrd makes it neigh impossible to get a shell 😤)

## Enrolling a FIDO2 security token

If something goes wrong, you will have to type your password or your recovery key. For safety, these should be long and complicated; but this means that it will be inconvenient to type them. Another option is to use a FIDO2 token (for instance a Yubikey).

To do that, install the FIDO2 optional library and tools:

```
pacman -S libfido2
```

Check that your FIDO2 token is detected:

```
fido2-token -L
fido2-token -I /dev/hidrawXXX
```

Enroll it:

```
systemd-cryptenroll --fido2-device=auto
```

-->

## Wrapping up

Some steps can probably be simplified a bit. In particular, we're running `mkinitcpio` a lot of times. We could check the name of the TPM module before rebooting, and add the module to `mkinitcpio.conf` earlier. (That's actually what I do when installing my systems.) I kept instructions in that order because that way, things are grouped in a more logical way and (I think) it's easier to understand if you're new to all this.

Finally, SecureBoot is not absolutely unbreakable. There are attacks against it. If you intend to store extremely sensitive data (e.g. military) in a volume encrypted with a key stored in a TPM, you should do some research beforehand. (But I hope that in that case, you're not following my blog for advice. That would be worrisome. :)) It's good enough for my use case, though (making sure that my data won't be readable by Dell technicians or second-hand hardware brokers who would end up with my dead laptop main board or its soldered-on disk).


[archinstallguide]: https://wiki.archlinux.org/title/Installation_guide
[rogueai]: https://rogueai.github.io/posts/arch-luks-tpm/
[mkinitcpio]: https://linderud.dev/blog/mkinitcpio-v31-and-uefi-stubs/
[systemdboot]: https://wiki.archlinux.org/title/Systemd-boot
[unlockluks]: https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
