---
layout: post
title: "Is Cloudflare overcharging us for their images service?"
---

I recently went down a very deep rabbit hole to understand why, some months, Cloudflare was charging us 3x what we were expecting for their Cloudflare Images service. I'm posting this write-up because back then, a quick search didn't turn anything up; and Cloudflare support has totally ghosted us for more than 8 months now.


## Context and scale

Let's get something out of the way first: this is not going to be a story about millions, or even thousands, of dollars. Merely hundreds. My partner [AJ] runs a website called [EphemeraSearch] which is an archive of old mail, a treasure trove for folks doing history or genealogy research. It's not making much money (yet!) but storing millions of postcards *does* incur significant hosting costs, so we're trying to be thrifty, since these costs come directly out of our own pockets (we don't have external investors, at least not yet).

The website itself was initially on Heroku, then moved to a self-hosted Kubernetes cluster (after a brief transition through AWS EKS, which turned to be awfully expensive, despite leveraging spot instances, very tight autoscaling, and the famously treacherous startup credits). Many third-party services are used whenever it makes sense; for instance, the search currently relies on Algolia.

Image hosting was initially using Cloudinary, but we knew from day one that it was only a temporary solution, as their pricing was prohibitive for us in the long run. We moved to Cloudflare Images because it seemed affordable enough at our scale (even though we'll almost certainly replace it later, too) and there is no question that Cloudflare is an excellent CDN.


## The problem

The service was working well, but after a few months, we noticed something off with our Cloudflare Images bills. At that point, we had a couple of million images, and less than a million image views per month. According to their [pricing] page, we should have been paying each month:

- $100 for image storage ($5 per 100,000 images stored, x 20)
- $10 for image delivery ($1 per 100,000 images served, x 10)

Instead, when summing our Cloudflare charges (as reflected on our credit card statements), we reached more than $400 some months.

What was going on?!?


## It should be easy, right

You might wonder, dear reader, “Why did you have to sum credit card charges to know your monthly bills? Don't you get invoices that would basically give you that information?”

Of course, the first thing we did was look at the invoices that we were getting. Despite the relatively simple billing models for storage and delivery, the invoices are more confusing than they should be, because the two dimensions of billing work differently.

**Image delivery** is a classic pay-for-what-you-use thing. It's $1 per 100,000 images served, *post-paid*. In other words, at the end of the month, Cloudflare counts how many images they've served, divides by 100,000, rounds up, and that's how much you pay in dollars.

**Image storage**, however, is prepaid, and you decide how many increments of 100,000 images you'd like to purchase. When you're close to running out, your account dashboard will show a warning message:

> Your account has 2% of its storage capacity remaining. Please add storage capacity to your account.

When you add storage capacity to your account, here is what happens.

First, you pre-pay immediately (and your credit card is charged) for the whole capacity that you're using, prorated to the remaining number of days in your billing cycle. In other words, if your new storage capacity is 1 million images, and you have 10 days left in your billing cycle, you immediately pay $16.67:

- 1 million images = 10 increments of 100,000 images at $5 each = $50
- 10 days remaining in a cycle of 30, so 50x10/30 = $16.67

Then, you get credited on your next bill with your *previous* storage capacity, prorated by the same amount - that's the time during which you will *not* use that capacity. In other words, if you upgraded from, say, 800,000 images when you have 10 days left to your current billing cycle, you get a credit of $13.33:

- 800,000 images = 8 increments of 100,000 images at $5 each = $40
- 10 days remaining in a cycle of 30, so 40x10/30 = $13.33

And finally, you receive a new invoice; meaning that in some months, instead of one invoice, you get multiple invoices with prorated charges. Fair enough.

At the end of the day (or rather, of the billing cycle), if we went from a capacity of say 800,000 to 900,000 and then again to 1,000,000, it looks like we should pay a prorated cost depending on how many days we provisioned each capacity. In any case, it should never cost more than 1,000,000 images, right?

*Wrong.*

As mentioned at the beginning of this post, in some months, instead of $110, our credit card charges were over $400, and we couldn't understand why.

*And neither could the Cloudflare support team.*


## Involving support

We contacted Cloudflare support in November 2023:

> I'm currently subscribed to Cloudflare Images with a capacity of 2,200,000 images. I've been adding many images in the last few months and am regularly adding capacity as needed. It's my understanding that each upgrade should be prorated.
> 2.2m images should cost $110/mo. However, when I look at the charges for the month of October, they add up to almost $400!
> September also exceeds $116 even though I had way less capacity then.

Cloudflare replied:

> [...] we've raised this issue with our Images team [...]

Then when we pinged them again some time later:

> [...] We are experiencing an unprecedented demand for our service, which is causing delays for our customers.
> I've submitted a request to our Engineering Team, so that we can thoroughly explain what happened, and if there was any mistake reagarding your Images service.

And after pinging them one month later:

> Please note that we are still working with the Engineering Team on this issue.

Then after 3 more months without an answer:

> Thank you for waiting. Please accept our apologies for the delay in responding to you. We are experiencing an unprecedented demand for our service, which is causing delays for our customers.
> Our Engineering team continues to analyze your case and develop a solution for your issue. We have been conducting weekly reviews of it for the past eight weeks. Rest assured, we are diligently working to resolve this matter.

After pinging them the Nth time, they pointed us to this [incident] which was indeed billing-related, but had absolutely nothing to do with our issue, alas.

We assume that our request was blindly lumped into the ongoing billing issue (even though our request dated from November 2023, and the billing issue ran through March-May 2024).

Last time we pinged support again, they had migrated support to Salesforce, so the original ticket seemed to be forgotten.

*Great.*


## Re-analyzing the situation

Making sense of the invoices was not trivial, because each invoice will potentially mention:

- itemized charges,
- an "available balance",
- a "previous balance",
- a "starting balance",
- a list of payments and credits.

That's a lot of different balances, with quite confusing names. To make sense of it, we ended up painstakingly entering all the transactions (meaning charges, payments, credits) into a spreadsheet, to try and see which balance actually corresponded to what, and to try to understand if and how we had been overcharged. That took a few hours of data entry, but eventually, it gave us the following graph:

![Graph of our charges, payments, credits, and running balance](/assets/cloudflare-images-charges.png)

And that's finally what helped us to understand what was going on.


## The explanation

When you change your provisioned image storage on Cloudflare Images, you pay for the new capacity upfront: your credit card gets charged immediately. Sure, it's prorated by the time remaining on your billing cycle, but the money goes out *immediately*. You get a credit for the old capacity that you won't use, but that credit will only show up on your next monthly bill.

Consider the extreme case where you would, at the beginning of your billing cycle, increase your capacity 5 times: each time, you pay for that capacity upfront; and you get a credit for the previous capacity but that credit only materializes the following month. On the next bill, you will see a very high negative balance (indicating that Cloudflare owes you a bunch of money) and your credit card will be charged less (or even not at all) that month, so things will eventually balance out. But in the meantime, you're accruing these credit card charges.

In the end, this means that Cloudflare was indeed overcharging us, but only temporarily: if enough time passes during which we *do not* change our image storage capacity, the balance should eventually go down until Cloudflare doesn't owe us money anymore.

The problem is that “changing capacity” is precisely the whole point of the hecking cloud. “Pay for what you use”. The first time I racked a machine in a datacenter in the 90s, I think we had at least a yearly commitment. In the 2000s it was fairly common to rent servers by the month, and by 2010 multiple cloud providers would let you rent machines by the hour, and then by the minute.

I don't know why Cloudflare decided to have this extremely weird mix of post-paid, cloud-like billing (for image delivery) and prepaid, not-cloudlike-at-all billing (for image storage), but here we are.


## Is Cloudflare Images any good?

We're happy with the quality of the Cloudflare Images service, but our needs are very modest, and it's definitely overpriced for our use-case.

If you need to store and serve *big* images (thousands of pixels in each dimension) and to resize them efficiently, Cloudflare Images might be interesting for you, because the pricing is exclusively based on the number of images, not their size. In our case, our images are typically in the 100KB-1MB range, and we only need a small number of variants for each of them.

It's likely that we will replace Cloudflare Images in the long run. Looking at storage costs alone, S3 would be 4 times less expensive *for our use-case*. And when we scale our image collection 10x, other solutions (like a couple of replicated, dedicated servers with 20 TB SATA disks) become 20x cheaper.


## Conclusions and thoughts

Many “indie” projects can easily fit on very cheap infrastructure and services, sometimes well within the free tier of some generous hosting providers.

In our case, however, the current scale of our collection (a few terabytes at the moment, and constantly growing) compared to the very low revenue (a trickle of sales commissions whenever someone ends up buying on eBay a postcard that they found through [EphemeraSearch]) means that we have to be very efficient with our (personal) funds.

In the IT industry, we often talk about “buy vs. build”. Over time, as we gain more experience and understand the complexity of the things we build, we often prefer to buy a quality service rather than cobble together a crappy version of our own, arguing that the time spent building it would better be invested somewhere else. In our situation, however, the bargain turns out a bit differently: now that this is *my* money, do I want to pay $1000/month for a service, or build it myself and run it on a $100/month server? How much time do I need to build and run that service; and can I reliably make $900/month by e.g. selling consulting services to cover that cost instead?

Preserving historical artifacts is not, unfortunately, something that investors or the capitalist system in general tend to favor. Let's hope that this changes in the future, but in the meantime, follow us for more thrifty and scrappy hosting tips ! 😁💸

*This post was reviewed by [AJ Bowen][AJ]. Any remaining typo or mistake is mine. We want to clarify that we think that Cloudflare Images is a great service, but that its pricing model (specifically, the prepaid aspect that has to be manually adjusted) is utterly borked. We hope our findings will be helpful to others!*

[AJ]: https://www.linkedin.com/in/ajbowen/
[EphemeraSearch]: https://www.ephemerasearch.com/
[pricing]: https://developers.cloudflare.com/images/pricing/
[incident]: https://www.cloudflarestatus.com/incidents/wsjmr28lwxw3
