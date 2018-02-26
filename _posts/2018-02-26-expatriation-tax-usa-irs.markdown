---
layout: post
title: Tax implications of relocating to the US
---

This is a boring post about boring tax stuff. It's boring but I wish I had known that when I moved to the US — it would have saved me more than $10K.

TL,DR: if you live in the US and own shares in foreign companies (even something tiny), you are supposed to declare it to the IRS each year. You won't be taxed on it, but you *have to* declare it. Nobody told me anything about that when I moved to the US. When I learned about it, the compliance procedure ended up costing me more than $10K. (It wouldn't have costed me anything if I had known ahead of time.)

This post will be interesting for people who are *US tax residents* and own stuff *outside of the US.* This is the case for many tech workers expatriating to the US, especially the ones who have non-zero work experience, because they are very likely to have earned some equity in their origin country: stocks, stock options, contributions to retirement plans ... And they are also very likely to have founded or taken participations in small companies. (And of course, this is not exclusive to tech workers!)

Keep in mind that this is just the results of my own research, relevant to my own situation. Your situation is probably different. Do your own research before deciding what you should or shouldn't do!


## Should I bother?

You should bother if you are a US tax resident *and* you own stuff outside of the US.


### Am I a US tax resident?

If you are a US citizen or a permanent resident (i.e. a green card holder), then you are a US tax resident, regardless of where you live and work. (This doesn't mean that you will pay taxes to the US; but you *must* file with the IRS every year.)

If you are in the US with a work visa (e.g. H1B or L1) and live in the US more than half of the year, you also are a tax resident. In other words, when you expatriate to the US, if you arrive before July 1st, you will probably be a tax resident the first year; otherwise you will start being a tax resident the second year.


### Do I own stuff outside of the US?

Almost certainly, yes. You probably have bank accounts, unless you closed them just before moving to the US.

The IRS wants to know about **everything** you own outside of the US. Yes, freaking **everything**.

Even your bank accounts should be declared (that's the infamous FBAR, for Foreign Bank Account Report), *except* if they are below $10K. Then you can skip them, because the IRS doesn't give a damn about amounts that low.

I was told about the $10K rule, so I thought I was fine, because I had less than $10K on my French accounts when I left France. But there are a few "gotchas."

First of all, what matters is not how much money you have at the end of the year, but the maximum value you had at any give point in time. In my case, that was fine, because I moved to the US in February and had been preparing for that before, so my French accounts had been low the whole year anyway. Cool.

Next, what matters is not individual accounts, but the aggregate (total) value. So if you have two accounts with $6K, you should report them.

Combining these two rules gets really interesting. One CPA told me that if you have $6K in one account, and move it to another account, then in theory it gets you above the limit. I couldn't find a definitive answer to that question, and it's not a huge deal anyway, but it shows how silly the whole thing can be. In my case, I was fine the first few years (I was just keeping a few thousand EUR in my French account to pay for my health insurance, my French mobile phone so I could keep my cell number, that kind of stuff) but a few years later, I ended up having more than $10K spread across a few accounts (yay lucky me!) so I had to declare these.

And finally, there is all the "non-money" stuff. You have shares in a company? You must declare them. Yes, even if you just have 1% in your buddy's tiny company. You have any kind of retirement plan — the foreign equivalent of an IRA or 401k? You must declare it. Again: you won't pay taxes on it, but the IRS wants to know.

Cherry on top: if you have access to foreign accounts that aren't yours, e.g. if you have a checkbook or are an authorized user on such accounts (because you're an admin for your company with overseas offices or whatever), you also have to declare that. But hopefully, if you are in that situation, your company will help you to do that. *Hopefully.*


## Come on, should I really bother ?!?

A.k.a, "what happens if I don't declare my stuff?"

This is a good question. 

We could unpack it in multiple sub-questions:

- What happens if I don't declare?
- How will the IRS find out, anyway?

The penalties are *brutal.* If you go through the Streamlined Foreign Offshore Procedures, which is a way to say "oops I didn't know I had to do that, so here are my updated tax returns" the IRS gives you a fine. The amounts vary. In my case is was about 5% of all amounts + tax preparation costs; a bit more than $10K. If you're good with administrative paperwork, perhaps you can do it yourself and save the tax preparation costs; but I'm not good with administrative paperwork, and I didn't want to screw up and I wanted to be in a good position if I get audited by the IRS.

If the IRS catches you, then it's a whole different story. The fines can reach $100K, or even *half of the value of the assets*. [This page on the IRS website](https://www.irs.gov/businesses/comparison-of-form-8938-and-fbar-requirements) will give you a rough idea. (They moved stuff around recently so I cannot find the page I had specifically for individuals.)

Now, how would they find out? They probably won't, if you have a relatively modest amount of money (less than $100K) and aren't constantly moving it around. Same thing if you have a modest amount of equity. However, the US (and a lot of countries with which the US has treaties and such) do have systems to report "high" transactions. Generally there are no pre-defined thresholds (to avoid people constantly staying below the threshold) but in theory, if a big amount of money (something between $10K and $100K) suddenly shows up on your account, your bank will very probably ask you where this comes from, and if you can't or won't tell, they alert TRACFIN (in France) or the local equivalent.

In 2010, the US voted the FATCA (not to be confused with the FACTA), which gives the IRS a better visibility on the foreign assets of US tax residents. This law was then progressively translated into treaties, on a case-by-case basis, with other countries. The IRS is trying to get rid of the bank secrecy of places that regularly qualify for the Tax Evasion And Other White-Collar Crimes Olympics, like Switzerland, Hong-Kong, Luxembourg … and the way they do that, is by pressuring foreign banks through their US branches. This means that as soon as your foreign bank knows that you are a US tax resident, they have to transmit information to the IRS. (Look up [FATCA AEI](https://www.google.com/search?q=FATCA+AEI) if you want to know more about that.)

In my specific case, it was a simple decision. I have a small amount of equity in Docker. If Docker eventually gets acquired or goes public, I hope that this equity will be worth a million USD or two. Perhaps more if my ex-coworkers do great. I don't know if that would make me rich enough to be on the radar for the IRS, but I didn't want to take any chances. I decided that it was safer for me to comply, and file (sometimes re-file) everything that was needed, to make sure that I'd be 100% clean with the IRS. This did cost me a bunch of money, but brought me a lot of peace of mind.


## PFIC and 5471

Now we get to the really ugly and annoying part, and this is where you will understand why there is more venture capital available in the US than anywhere else.


### If you own more than 10% of a foreign company

If you own more than 10% of a foreign (non-US) company, this company must file a form 5471 to the IRS. If the company doesn't do it, then *you* must do it. What the hell is that form? As I understand it, it is a kind of financial x-ray for the IRS. It has a lot of accounting and legal information about the company.

This is mind-blowingly annoying, because just *preparing* that form is going to cost you about $500 per year. (Some CPAs can be cheaper, or more expensive; that's just an average.)

Yes, if you own 25% of a company worth 4,000 EUR, somebody must pay $500 every year so that you can file your US taxes correctly.

You may want to sell these shares before moving to the US, *just in case.* Again: the IRS probably doesn't give a damn about it, but *if they wanted, they could screw you big time.*


### Passive Foreign Investment Companies

If you own shares in a PFIC, things also get complicated. "Jérôme, I never heard about PFIC before, so I'm pretty sure that I don't own shares in one!" **Wrong.** I had shares in a PFIC even though I had no idea!

A few years before moving to the US, I had invested into a company in France. But I didn't invest *directly* in the company. I invested in a *holding*, and the holding invested in the company. This allows the company to keep a simpler "cap table" (list of people owning shares), since instead of having 10 extra investors, they have one — and that investor is a company regrouping the new 10 investors. It makes things simpler for a lot of people.

Except that this holding is then considered as a Passive Foreign Investment Company, or PFIC. (If you want a moderate amount of details, you can check the [Wikipedia definition for PFIC](https://en.wikipedia.org/wiki/Passive_foreign_investment_company#Definition).)

Alright, what does that mean in practical terms? First of all, more forms and paperwork. And also, since this PFIC value was in Euros, the value (converted to USD) did change over time. And therefore, I had to report capital gains and losses — even though I didn't buy or sell anything, even though that company didn't buy or sell anything, even though my shares didn't generate any dividends whatsoever. Sounds completely crazy? Yup!


## Consequences for investors

This means that if I want to invest money outside of the US, it will incur significant overheads for me at tax season. Of course, if I'm investing one million dollars, I probably don't care paying $1K every year in extra tax preparation fees. But for more reasonable amounts ... Even at $100K, these fees will wipe out almost 1% of the investment each year. (And of course, any gains that you realize will be taxed on top of that.)

That's one of the reasons why it's way easier, as a startup, to find capital in the US than anywhere else. Because the US tax law makes it inconvenient and expensive for US investors to put their money abroad. Next time you hear people complaining about how it's hard to raise seed money outside of the US, think about it.


## The bottom line

All these reporting requirements are primarily intended to track money laundering and tax evasion schemes, which are noble endeavors. It ends up imposing absurd constraints on completely lawful individuals, but since these individuals are either foreign nationals living in the US, or people investing abroad (i.e. money getting *out* of the US), the US have zero incentive into making that less complicated.

One the one hand, a lot of these requirements and constraints are "rich people problems," applying to you only if you're wealthy enough to invest or own equity. On the other hand, it is increasingly frequent in the tech sector to be compensated with stock or stock options, so you may qualify sooner than you think!

The really important bit is that if you are aware of these requirements ahead of time (i.e. before expatriating to the US), you can save yourself a lot of trouble (and money) by making sure that your bank accounts are below $10K, and selling your stock — or at least deciding what is worth keeping.

*We'll be back soon with more exciting posts about container technology, devops, mental health, and diversity!*
