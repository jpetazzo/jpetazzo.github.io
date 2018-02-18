---
layout: post
title: Seven years at Docker
---

TL,DR: I have left Docker Inc. to take a sabbatical and recover from depression and burnout. I plan to dedicate the next six months to family, friends, meditation, music, and generally speaking, enjoy life to recharge for whatever will come next.

*This text is an adaptation of the message that I sent last week to my coworkers to announce my departure. I'm now sharing it with a wider audience, because mental health is serious stuff, and I wish we all felt more comfortable talking about it. I also wanted to share with my friends, the Docker community, the container ecosystem, and beyond, some thoughts about what has been for me an incredible journey.*

February 6th was my last day at Docker. Seven years and one day earlier, I boarded a big bird of metal that would take Sam Alba, Sébastien Pahl, and me from Paris to San Francisco, and we joined the dotCloud office on Third Street. I couldn't imagine What Would Happen Next.

![Five persons around a table in a conference room](/assets/dotcloud-foundersden.jpg)

*The dotCloud office at Founder's Den, early 2011. (Credit: SFGate)*


## From dotCloud to Docker

In 2011, our tiny startup was fearlessly competing with Heroku, which had just been acquired by Salesforce for $250M. We were the first PaaS to support so many languages and databases, thanks to the extensive use of this obscure kun-tay-nerr technology. You could count our engineering team on one hand, and all of us were both on-call and doing customer support. We had weekly contests about who would solve the most support cases.

In 2012, I gave [my first "real" talk at a "real" conference.](http://pycon-2012-notes.readthedocs.io/en/latest/dotcloud_zerorpc.html)
It was about the other cool piece of tech at dotCloud: our [ZeroRPC](http://www.zerorpc.io/) library. (One of the Xooglers who joined us back then even told us, "I wish we had something that simple and straightforward at Google!") I'm grateful for the incredible work that my peers had put into this project, as it enabled me to speak at PyCON, and encouraged me to try and speak at more conferences.

In 2013, you know what happened: [Solomon Hykes presented Docker](https://www.youtube.com/watch?v=wW9CAH9nSLs) at the same PyCON conference (one year later), and over the following months, the whole dotCloud engineering team shifted to Docker. Meanwhile, I gave [my first container talk](https://www.socallinuxexpo.org/scale11x/presentations/lightweight-virtualization-namespaces-cgroups-and-unioning-filesystems.html) at the SCALE conference in Los Angeles; and after that talk, I was invited to present Docker in Beijing, and then in Moscow. These were incredible opportunities, both personally (I forged some long-lasting friendships during these trips) and professionally: thanks to our combined efforts, we were able to issue joint statements with [Baidu](https://blog.docker.com/2013/12/baidu-using-docker-for-its-paas/) and [Yandex](https://techcrunch.com/2013/10/16/search-engine-giant-yandex-launches-cocaine-a-cloud-service-to-compete-with-google-app-engine/), announcing that they were now using Docker!


## From SRE manager to evangelist

In 2014, I gave an average of two talks per week; but most importantly, I spoke at [LinuxCon](http://sched.co/1jQlrdl), [OSCON](https://conferences.oreilly.com/oscon/oscon2014/public/schedule/detail/34136), and [LISA](https://www.usenix.org/conference/lisa14/conference-program/presentation/turnbull).
I would have been satisfied with my career if it had given me the opportunity to *attend* these conferences; but now I was *speaking* there (and would be, multiple times). Again, this wouldn't have been possible without the fantastic work done by the Docker core team. Being a developer advocate or an evangelist is generally hard; but it's markedly easier when your product is as helpful and as approachable as Docker. That year, I also turned down an invitation to speak at AWS re:invent because they didn't have a code of conduct back then. (They eventually added one; probably not by my sole request, but I like to think that it contributed!)

In 2015, `[HEAVY SPEAKING INTENSIFIES]`. I enabled our partners in Europe by training about a hundred customers and other trainers in a couple of weeks, and gave my first keynotes in [Paris](https://www.youtube.com/watch?v=sDRbKcz3QWU) and [São Paulo](https://qconsp.com/sp2015/speaker/jerome-petazzoni.html). For the first time, I found the courage to speak on stage about sexism and harassment in open source communities, and the reactions I got made me realize that these problems were far worse and more prevalent than I had thought. I was on stage [7 times](http://events17.linuxfoundation.org/events/archive/2015/linuxcon-north-america/program/schedule) at LinuxCon that year, and I still don't know if that deserves an entry in the wall of fame or shame. I finally spoke at re:invent, and it was [ridiculous](https://www.youtube.com/watch?v=7CZFpHUPqXw). During that whole time, I was helped and empowered by the whole Docker team to give my best: engineering was always here for me if I had a tricky last-minute technical question; and I could also rely on everyone else in the company for logistics and overall support. That made a huge difference.


## From busy to burned out

In 2016, in addition to my regular talks, I delivered an increasing number of orchestration workshops. Unfortunately, that's also when I found my limits. I should have been kinder with myself; but I didn't realize it until it was too late: my mental state deteriorated until I was diagnosed with depression in October. Fortunately, by that time, the company had many fantastic speakers among its ranks; and the [Docker Captains](https://www.docker.com/community/docker-captains) program had taken off — so there was no negative impact when I shifted my focus.

I started antidepressants and therapy. Results were not encouraging at first; but after switching medication twice and finally being referred to a psychatrist, my symptoms became easier to manage. I started having more energy, so I used it to take care of myself and do things that would make me happy. Cooking fine meals. Reading. Learning the cello. Dating. [Building cool stuff with Raspberry Pis](https://www.youtube.com/watch?v=gsw23mAHxk4). Eventually, things got better.

In 2017, I continued to deliver workshops, and I helped to shape DockerCon's Black Belt track. It's hard to find words to describe how much joy and satisfaction I drew from this opportunity. In Austin, the Black Belt track is the track that got the highest ratings *and* attendance. I also improved the diversity of that track: in Copenhagen, the majority of the talks featured a speaker from a traditionally underrepresented background. Reaching out to these outstanding speakers, helping them when necessary, sometimes coaching them, has been one of the most rewarding steps of my career; and there again, I would never have been able to do it without the full support of our team.

![Group picture with the Black Belt Track speaker at DockerCon 2017 in Austin.](/assets/2017-04-black-belt-track-austin.jpg)

*Black Belt track speakers from DockerCon 2017 in Austin.*

In the summer of 2017, while participating in a study about mental health, expatriation, and remote teams in the tech industry, I took the [Maslach Burnout Inventory](https://en.wikipedia.org/wiki/Maslach_Burnout_Inventory). The MBI is a test to assess burnout factors. I was in the red zone. Alas, neither my GP nor my psychiatrist knew much about burnout, and I felt on my own. Out of sheer coincidence, I ended up talking to a doctor who was more knowledgeable on that topic. I will write more about this in the future; but long story short, I in September, I decided that I needed to take a break in 2018.

Before taking that break, I focused my energy on Docker's Kubernetes strategy. One week after we announced support for Kubernetes plans in Copenhagen, I was delivering a [Kubernetes workshop at ContainerCon](http://sched.co/BzLR); and I delivered that workshop 3 times internally at Docker (which gave me the perfect opportunity to visit our Raleigh office and hang out with the wonderful folks there!). The materials are available on [kube.container.training](http://kube.container.training/), by the way.

The last two months of 2017 were a grueling struggle to figure out what would be the best way for me to take that break. I wanted to take at least 6 months off, which is more than the 12 weeks allowed by the FMLA. (The FMLA allows employees to take up to 12 weeks of unpaid leave.) Docker doesn't have a sabbatical program, and didn't want to create one. My doctors didn't want to fill out the paperwork that would have allowed me to take a medical leave of absence. Switching doctors wouldn't help because filling that kind of paperwork for mental health reasons requires to be seen over a longer period of time; and I didn't want to wait 3 or even 6 more months — to perhaps be denied my leave anyway. So my only solution was to quit. This would have been a financially difficult proposition, but I was able to sell a large chunk of my equity in Docker in 2017, meaning that I have a comfortable safety net for now.


## From startup to sabbatical

In 2018, I'm going to take a lot of time for myself. I'm learning Rust. I'm [writing a tiny Ableton clone](https://www.youtube.com/watch?v=IkKDVlW2WPk) to connect a grid controller (like the Monome or the LaunchPad) to a Raspberry Pi to play live music. I'm going to do a Vipassana meditation retreat. I hope to mentor folks who weren't as lucky and privileged as I was, and be a better ally. The first step was to quit Docker, and that was the most difficult one; but the road ahead looks great.

A lot of people have asked me if I would be joining Heptio / Microsoft / some other company, and some folks asked if I'd be open to some consulting gigs. First of all, while I would be humbled and honored to be deemed fit to work with teams like Heptio's or some of the Azure folks, I don't plan on going back to full-time employment until at least September. As for consulting, sure! You can [contact me here.](https://docs.google.com/forms/d/e/1FAIpQLSeqzL4GHkY87cFBfMpsrKyisX-ujpD1pcuZ0kn4SvJkj2ML5w/viewform)


## From me to you

One last thing — all the achievements that I listed above are not mine alone.
I assume that you mostly saw my happy, productive, engaging side during all these years; but one person in particular also had to deal with me when I was heavily depressed, exhausted, struggling to perform the simplest tasks, and much less interesting to be around. [My partner](https://twitter.com/s0ulshake) since 2014 supported me unconditionally all that time, and helped me walk through some of my darkest moments. I owe her more than words can tell.

I also owe to a very long list of coworkers, friends, and everything in between.
 If we've worked together or collaborated in any way; if you've been a supportive ear or even just a smile during these years — I want you to know that these successes are also yours.
I hope that our paths will cross again and that the future holds many opportunities to help each other.

Peace,

jpetazzo out 🎤💨🤚
