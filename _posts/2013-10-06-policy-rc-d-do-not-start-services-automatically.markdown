---
layout: post
title: "Use policy-rc.d to prevent services from starting automatically"
---

When you install (or upgrade) a service, the package manager will try to
start (or restart) this service. If you are working on a normal server,
this is usually what you want. But if you are inside a `chroot` environment,
or maintaining some kind of [golden image], you don't want to start services.
If you are using Debian/Ubuntu-based distros, there is a super easy way
to solve the problem: the `/usr/sbin/policy-rc.d` script.


## Sysadmin inhibits service start and stop with this weird trick

When anything needs to start and stop services on Debian or Ubuntu, it
doesn't invoke init scripts directly: it goes through `invoke-rc.d`.
So, instead of doing `/etc/init.d/foobar start`, a well-behaved
`postinstall` script should do `invoke-rc.d foobar start`. It will
do exactly the same thing, *except* that it will run `policy-rc.d foobar
start` first. (If `/usr/sbin/policy-rc.d` doesn't exist, it is skipped.)

The `policy-rc.d` script has only one job: it should tell to `invoke-rc.d`
if the action is allowed or not, by using its exit status. An exit status
of `0` means "action allowed"; an exit status of `101` means "action not
allowed". There are other possibilities, for more complicated scenarios.
You can read the details in the invoke-rc.d [interface] documentation.

So, to prevent services from being started automatically when you install
packages with dpkg, apt, etc., just do this (as root):

    echo exit 101 > /usr/sbin/policy-rc.d
    chmod +x /usr/sbin/policy-rc.d

If you're not root, you can use the `sudo tee` trick, i.e.:

    echo exit 101 | sudo tee /usr/sbin/policy-rc.d
    sudo chmod +x /usr/sbin/policy-rc.d


## Why she got no bangs?

If you already knew about `policy-rc.d`, here is a second chance to learn
something new today :-)

You might be wondering "shouldn't I put `#!/bin/sh` in the beginning of
the policy-rc.d script?"

If there is no [shebang] at the beginning of the file, the OS will try to
execute it as a "normal" binary. The `exec*` syscall will fail with
`ENOEXEC` (Exec format error). Well, unless your script happen to
conveniently have an ELF signature (or another binary signature recognized
by your system), but this is very unlikely.

What happens next depends on the calling program.

The `exec*` wrappers in the libc will try to use `/bin/sh` as a fallback
to invoke the program -- which is why I didn't deem necessary to add a
shebang to the policy-rc.d script.

However, if you are running a shell, it will use itself as a fallback.
In other words, if you call the policy-rc.d script from `bash`, then
`bash` will be used to execute it.

And if you are doing "raw syscalls", you will receive an unadultered
`ENOEXEC` error, and can do whatever you want to handle it. This is
the case if you try `os.execv(...)` in Python, for instance.

Isn't that great? :-)


[golden image]: http://searchservervirtualization.techtarget.com/definition/golden-image
[interface]: http://people.debian.org/~hmh/invokerc.d-policyrc.d-specification.txt
[shebang]: http://en.wikipedia.org/wiki/Shebang_(Unix)