---
layout: post
title:  "First post with Jekyll"
---

This is the blog I should have setup 15 years ago. Here I will
talk about cool hacks, cooking, cocktails, books I've read
(or sometimes I haven't), linguistics... And I decided to use
[Jekyll][] to run it.


## Why this blog?

I love to share about the stuff I do. At `$WORK` I manage ops
for the [dotCloud][] PaaS, and I spread the word about lightweight
virtualization, Linux Containers, and [Docker][].
This content has been published on the [dotCloud blog][] or the
[Docker blog][].

But, I would also like to talk about other topics, not related to
my work (or not directly). So I had to do something I had postponed
for the last 15 years or so: setup my own blog :-)


## Why Jekyll?

When I wrote my recent entries for the Docker blog, I drafted them
in Markdown format, using [Gist](http://gist.github.com/) as a scratchpad.
I like neat, lean markup formats like [reStructuredText][] and [Markdown][].
Moreover, I want to be able to write efficiently during my commute, or
when in planes. (I don't fly so often, but when I do, I'd rather make it
producitve if I can't get some sleep.)

I don't remember how I learned about [Jekyll], but it was exactly
what I was looking for: a decent blogging system, apparently designed
to work with plain text source files. The [GitHub Pages][] integration
is the icing on the cake.


## First steps with Jekyll

I did a local install of Jekyll using [Stevedore]. I will talk more about
Stevedore another time; but to give you an idea, it was as simple as:

```bash
jpetazzo@tarrasque:~$ stevedore new jekyll
jpetazzo@tarrasque:~$ stevedore enter jekyll
jpetazzo@stevedore-jekyll:~$ sudo apt-get install -qy ruby1.8 rubygems1.8
[...]
jpetazzo@stevedore-jekyll:~$ gem install jekyll
[...]
jpetazzo@stevedore-jekyll:~$ jekyll new jpetazzo.github.io
jpetazzo@stevedore-jekyll:~$ cd jpetazzo.github.io
jpetazzo@stevedore-jekyll:~/jpetazzo.github.io$ jekyll serve --watch --drafts
[...]
  Server running... press ctrl-c to stop.
```

Then in a different terminal:

```bash
jpetazzo@tarrasque:~$ stevedore url jekyll 4000
http://10.1.1.7:4000/
```

Then, I essentially started to customize the CSS and HTML templates
a little bit, and wrote this.

Once I was happy with the result, I did a `git init`, added a `.gitignore`,
committed everything to the [appropriate GitHub repository](
https://github.com/jpetazzo/jpetazzo.github.io), and there you go!


## What's next?

I will probably tweak the layout a little bit to make it nicer (or less ugly),
maybe add some Twitter feed and/or nicer social links; and obviously, write
more exciting content!


[Docker]: http://docker.io/
[Docker blog]: http://blog.docker.io/
[dotCloud]: http://www.dotcloud.com/
[dotCloud blog]: http://blog.dotcloud.com/
[GitHub Pages]: http://pages.github.com/
[Jekyll]: http://jekyllrb.com/
[Markdown]: http://daringfireball.net/projects/markdown/syntax
[reStructuredText]: http://sphinx-doc.org/rest.html

