---
layout: post
title: "Juniors, seniors, and mentors"
---

What's the difference between a junior and a senior software engineer?
Is it the responsibility of a company to provide learning resources
(e.g. time or mentoring) to its engineers? What makes a good mentor anyway?

All these questions are particularly important in the context of
software engineering, a discipline where the tools and frameworks
and languages evolve very quickly. At a first glance, it seems like
we need to keep learning if we want to be good at what we do.
How can we make that work?

*Note: this post is about software engineering roles and practices.
It is likely that many of the points still hold in other fields—i.e.
engineering in general, or non-engineers in software companies;
but reader's discretion is then advised.*


## Juniors and seniors

For a while (at least the first decade in my career in software), I
never really thought too hard about what it meant to be a "junior"
or "senior" engineer. It was probably something that came with
experience, I thought. After some time in the industry (how long?)
I would be able to tack "senior" next to my title, and that would
be about it.

And then, someone challenged this thought process. It was in 2014,
at the [SCALE 12x](http://www.socallinuxexpo.org/scale12x/)
conference.
[Lars Lehtonen](https://twitter.com/alrs) said approximately this:

> The primary skill of senior engineers is to train junior engineers.
> If you're senior with no junior around, you're not senior.

If you want the full context of that quote, you can check the
[recording of that talk at the LISA conference](https://www.usenix.org/conference/lisa14/conference-program/presentation/lehtonen)
(the quote about junior engineers is a bit after the 19" mark).

There are multiple ideas packed in there.

First, in every project, there will be some work that will
be exciting and a great learning experience if it's one of the
first times we do it, but less interesting if we have done
this 10 times in previous jobs or projects already.

It's great to have someone "junior" to do that kind of work;
with the help and supervisior of someone "senior". It will free up
some time for the "senior" engineer, while helping the "junior"
one to ramp up their skills.

Under that lens, the term "junior" just means
"someone who has done less, and/or has less experience with,
*a specific task or tasks in a specific domain*", by contrast
with "senior". In other
words, junior/senior is domain-dependent and team-dependent:
we can be senior in one field (e.g. databases, containers), junior in
another (e.g. frontend, machine learning). We can be senior
relative to one team, and junior relative to another.


## Juniors and janitors

Of course, the actual situation is not always as rosy as I
described above. Sometimes, junior engineers are tasked with the
boring and repetitive grunt work. Less
exciting, for sure, but in the right environment, that can still
be a great opportunity to learn and grow, for instance by
trying to automate that work.

This is part of a larger conversation
about the different kinds of tasks that need to be done when
building and then scaling and operating an application.
My favorite talk on this topic is
[Rock Stars, Builders, and Janitors](
https://www.youtube.com/watch?v=eZp3W4qYhJc) by
[Alice Goldfuss](https://twitter.com/alicegoldfuss).


## Juniors and saviors

In this context, it means that we shouldn't assign exclusively
janitorial tasks to our junior team members. But it also
means that conversely, if our team is overworked and short-handed, and
our senior engineers don't have the time to do
all the complex, value-adding stuff that we'd like them to do,
one easy and cost-effective solution is to hire some junior
engineers. After a short ramp-up period, they will be able to take
over the less complex tasks, freeing up time for the rest of
the team.

After a while, junior engineers are not junior anymore, and
we now have a better, stronger team. After I
[wrote about my
experience with depression and burnout](
http://jpetazzo.github.io/2018/02/17/seven-years-at-docker/
), many people reached out to share their stories; and
I heard more than a few terrifying ones where an entire team
was wiped out by burnout, one after the other, because after
each departure, the workload and the overall situation got
worse for the remaining people, and management failed to
course-correct in a timely manner. The more you wait, the more expensive
it gets to fix a situation like this one—not even mentioning
the appalling damage caused by burnout. *Hire junior engineers and
train them before your best people start leaving in droves.*


## Learning resources

Training people requires adequate resources. How do we do that?

Everyone learns differently, and every organization has different
budgets and people anyway.

Let's start with the obvious: we should give time for people to
learn and grow during office hours. We shouldn't expect our employees
to spend their evenings and week-ends learning new things. Otherwise,
we are penalizing people who *cannot* invest that time, for instance
because they are parents or generally speaking caretakers.

To [quote Jen Simmons](
https://twitter.com/jensimmons/status/1022536206314352641):

> If you are spending a lot of your time learning *while* you code — while someone is paying you — then you are doing it right. You don’t need to learn it all ahead of time and show up to work already knowing. ...

> Learning on the job is the job. You’ll accumulate wisdom as you go. You’ll learn to recognize & prevent complex problems earlier & earlier in the process. But you’ll *never* reach a place where you don’t have to look things up, don’t haveto keep learning (on someone else’s dime).

To progress in our careers, we need to keep learning and pick up
new skills. If we cannot do that, we are stuck.

I should clarify, here, that there is nothing wrong with using
your free time to gain new skills and work on side projects.
It is very likely that this will accelerate your career, of course.
Therefore, somebody with more free time and fewer responsibilities
is likely to progress faster than a single parent taking care of
two young kids and an elder while having to endure a long commute.
Such is life. But our responsibility is to make sure that we
*give enough time* for everyone to keep progressing, so that we
don't build an environment that is downright hostile or toxic for
less privileged folks.


## Always be learning

Some people might be thinking, "but we want to hire engineers that
are productive from day 1; we select them because they have the
set of skills that are required for the job, so that they can be
operational faster!"

Oh dear, I have a few things to break down to you.

In most big organizations (or, really, any place that has been
around long enough to have a non-trivial stack), it will take
weeks and even months to properly on-board an engineer. Yes,
we keep touting how containers help us reduce friction, and how
good infrastructure and platform tools enable us to push code
with confidence very early after joining a team; but even with all
that, every engineer at Facebook goes through a [six-week bootcamp](
https://www.facebook.com/notes/facebook-engineering/facebook-engineering-bootcamp/177577963919/). I've heard a few
times that it could take 3 to 6 months for engineers at Google
to reach acceptable levels of productivity. (Keep in mind that
there are, of course, outliers; these are just averages.)

In the big picture, it doesn't matter if a new hire has to spend
a few days or a week getting familiar with the specific framework
that you're using, or the API of your Cloud provider.

"But we are a startup; we can't afford to wait months for people
to be adding value!"

If you're a startup, your employees need *even more* to keep
learning, because your technology stack and your processes are
even more likely to evolve than in a bigger company. On the other
hand, if you are at an early stage, your existing stack is
hopefully less complex, and they can get started faster—but
they will still learn *a lot* during the first weeks and months.

I'm going to give you a personal example. When I joined dotCloud,
the infrastructure was 99% AWS EC2. I had zero experience with it
(I had perhaps fired up an instance with the console before; but
I had never used the CLI or API and I wasn't familiar with the
specifics of AWS). I also had zero experience with ZeroMQ and
MessagePack, which were powering the RPC layer used all over the
place by dotCloud. That didn't prevent Solomon Hykes and Sebastien
Pahl from hiring me. If memory serves me well, one of the first things
that I had to do was to add SSL termination to some services, in
a reproducible, automated way. I spent some time messing around
with ELBs, only to discover that there was a limit to the number
of certificates that we could load back then, and that it wouldn't
work for us. Then I switched to small EC2 instances running NGINX
instead. There is a good chance that somebody familiar with AWS
wouldn't have been faster, or not by much. Furthermore, while
working on this, I also contributed useful features to the RPC
layer (again, if memory serves me well, by improving introspection
features and auto-documentation, making it easier for me but also
others engineers to discover the services that we were running
and how to use them without having to pull up their source code
each time). On that topic, requiring a candidate to know
beforehand about ZeroMQ and MessagePack would probably have reduced
the potential talent pool to unacceptable numbers anyway.

Louder for the folks in the back: **you shouldn't hire people
for their *current skills*, but for their ability to pick up
the new skills that they will need** to do their job tomorrow,
next month, next quarter, next year. Very few software engineers
knew about containers in 2013 when Docker launched. Millions of
developers learned how to use Docker and containers since then;
and most of them learned on the job, for the greater satisfaction
of their employers.


## Mentors

There is another resource that is crucial to the development of
good engineers: mentoring.

What's that, exactly?

The first thing that comes to mind is usually a long-term,
ongoing, one-to-one relationship
between a more senior and a more junior person (see, we're back
to the junior/senior theme). I want to use a broader definition,
so that it encompasses any kind of situation where someone takes
some time to help someone else by providing them with information
of any kind that they need to better do their job.

Here are a few examples of situations that many people would
probably not consider as "mentoring", but that I would like to
put under that broader definition.

- I'm getting started with a new project or in a new team, and
  a coworker is helping me to set up my environment, walking me
  through code, docs, wikis, tickets, whatever.

- I am different from most of my coworkers, in a way that might
  be obvious or subtle, and somebody in the company (potentially
  outside of my team) has regular check-ins with me. This is useful
  if I'm the only woman in a team of men, or the only person of
  color in a team of white people, or the only person with a different
  native language, or the only person coming from a different
  education background.

- I'm part of a cross-functional effort involving multiple teams
  with very different domains, and I often need to ask for information
  or clarification from other teams.

- I'm a more junior team member, and I need frequent guidance and
  help from other engineers in the team or other employees in the
  organization. (This is a bit like a traditional mentoring situation,
  but shared across multiple people instead of having a designated mentor.)

**How much mentoring should we provide? As much as necessary.**

**Is there such a thing as "too much mentoring"? No.**

If we find ourselves thinking, "we are spending too much time training
new people", or similarly, "our senior engineers can't get anything done
because the new hires are taking too much of their time", then we
should re-read [that paragraph](#juniors-and-saviors). The better we
help new hires to ramp up their skills, the faster they will be able
to accomplish complex tasks and free up time of our senior engineers.

From what I've seen in various organizations, when people complain
that "this employee is taking too long to be operational", they are
shifting the blame to the employee, while very often,
the actual reasons are:

- lack of on-boarding process;
- lack of documentation;
- unequal access to mentors or other resources;
- cultural bias;
- negative attitude towards asking questions.

Individually, these things can hinder someone's progress; and
combined, they can be even more damaging. For instance, if we don't have
proper documentation explaining how to set up a new hire's environment,
and rely on Alice to do it each time, anyone starting while Alice
is on vacation will appear to be slower than the others, even if
it's totally not their fault.

Another example: if only Bob knows the ins and outs of our database
setup, and the only way to get information is to sit with him at his
desk, this puts remote workers at a disadvantage. If Bob also has
bias (which is likely, because Bob is human and all humans have bias),
he might not communicate as easily with people who are different from
him, and therefore put them at a disadvantage.

Encouraging people to ask questions (rather than discouraging them
by sending them the message that they should already know everything,
and that asking questions is a sign of weakness) can also make a huge
difference. Foster a culture where asking questions is normal and
expected, regardless of experience and seniority.

Eventually, once we have fixed our on-boarding processes, documentations,
made sure that key people were available in a fair manner, and trained
our people to reduce the impact of bias, if someone is still a poor
performer, letting them go might be the only option; but it should be
done as fairly as possible, and see that as an opportunity to improve
our hiring process. But I digress!


## Always be teaching

The other side of the coin is that as an engineer, regardless of my
level, *teaching* should be part of my core skills. It doesn't mean
that every engineer should be able to build a course curriculum,
deliver a tutorial, give a talk, or anything like that;
but every engineer should be able to answer questions from a peer of any level.

Learning is a critical skill for a good software engineer,
but teaching is just as important.
An awesome 10x engineer who can't or won't share what they know
only brings short-term value to your organization. In the long
term, they will become a liability: at best, by being gatekeepers
to important information; at worst, by driving other people away.


## Conclusions

To recap, a senior engineer might be more experienced in some areas,
but first and foremost, they should be someone who is able
and willing to share what they know.

Everyone (not only junior engineers) needs mentoring and easy
access to information, during their whole career.

There is no such thing as too much mentoring.

We should promote cultures and environments where asking
questions is always OK.

All these things will pay off quickly and make us more effective!

*Thanks to [AJ](https://twitter.com/s0ulshake) for proofreading an early
version of that post and suggesting many fixes and improvements. All
remaining typos and mistakes are mine.*

