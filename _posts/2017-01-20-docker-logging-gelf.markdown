---
layout: post
title: Adventures in GELF
---

If you are running apps in containers and are using
Docker's GELF logging driver (or are considering using
it), the following musings might be relevant to your
interests.


## Some context

When you run applications in containers, the easiest
logging method is to write on standard output. You can't
get simpler than that: just `echo`, `print`, `write`
(or the equivalent in your programming language!)
and the container engine
will capture your application's output.

Other approaches are still possible, of course; for
instance:

- you can use syslog, by running a syslog daemon in your
  container or [exposing a /dev/log socket](/2014/08/24/syslog-docker/);
- you can write to regular files and [share these
  log files with your host, or with other containers,
  by placing them on a volume](https://www.digitalocean.com/community/tutorials/how-to-work-with-docker-data-volumes-on-ubuntu-14-04);
- your code can directly talk to the API of a logging service.

In the last scenario, this service can be:

- a proprietary logging mechanism operated by your
  cloud provider, e.g. [AWS CloudWatch] or [Google Stackdriver];
- provided by a third-party specialized in managing logs
  or events, e.g.
  [Honeycomb], [Loggly], [Splunk], etc.;
- something running in-house, that you deploy and
  maintain yourself.

If your application is very terse, or if it serves
very little traffic (because it has three users,
including you and your dog), you can certainly run
your logging service in-house. My [orchestration
workshop] even has a [chapter on logging] which might
give you the false idea that running your own
[ELK] cluster is all unicorns and rainbows, while
the [truth is very different](https://twitter.com/alicegoldfuss/status/811009771583074304)
and [running reliable logging systems at scale is hard](https://twitter.com/alicegoldfuss/status/725534286351233024).

Therefore, you certainly want the possibility to send
your logs to *somebody else* who will deal with the
complexity (and pain) that comes with real-time storing, indexing, and
querying of semi-structured data. It's worth mentioning
that these people can do more than just managing your logs.
Some systems like [Sentry](https://sentry.io/welcome/) are
particularly suited to extract insights from errors (think
traceback dissection); and many modern tools like
[Honeycomb] will deal not only with logs but also any kind
of event, letting you crossmatch everything together
to find out the actual cause of that nasty 3am outage.

But before getting there,
you want to start with something easy to implement,
and free (as much as possible).

That's where container logging comes handy. Just write your
logs on stdout, and let your container engine do all the work.
At first, it will write plain boring files; but later, you
can reconfigure it to do something smarter with your logs —
without changing your application code.

Note that the ideas and tools that I discuss here are orthogonal
to the orchestration platform that you might or might not be using:
Kubernetes, Mesos, Rancher, Swarm ... They can all leverage the
logging drivers of the Docker Engine, so I've got you covered!


## The default logging driver: `json-file`

By default, the Docker Engine will capture the standard output
(and standard error) of all your containers, and write them
in files using the JSON format (hence the name `json-file` for
this default logging driver). The JSON format annotates each
line with its origin (stdout or stderr) and its timestamp,
and keeps each container log in a separate file.

When you use the `docker log` command (or the equivalent API
endpoint), the Docker Engine
reads from these files and shows you whatever was printed
by your container. So far, so good.

The `json-file` driver, however, has (at least) two pain points:

- by default, the log files will grow without bounds,
  until you run out of disk space;
- you cannot make complex queries such as "show me all the HTTP
  requests for virtual host `api.container.church` between
  2am and 7am having a response time of more than 250ms but
  only if the HTTP status code was `200/OK`."

The first issue can easily be fixed by giving [some extra
parameters](https://docs.docker.com/engine/admin/logging/overview/#/json-file)
to the `json-file` driver in Docker to enable log rotation.
The second one, however,
requires one of these fancy log services that I was alluding to.

Even if your queries are not as complex, you will want to
centralize your logs somehow, so that:

- logs are not lost forever when the cloud instance running
  your container disappears;
- you can at least `grep` the logs of multiple containers
  without dumping them entirely through the Docker API or
  having to SSH around.

*Aparté: when I was still carrying a pager and taking
care of the dotCloud platform, our preferred log analysis
technique was called "Ops Map/Reduce" and involved fabric,
parallel SSH connections, grep, and a few other knick-knacks.
Before you laugh of our antiquated techniques, let me ask
you how your team of 6 engineers dealt with the log
files of 100000 containers 5 years ago and let's compare
our battle scars and PTSD-related therapy bills around
a mug of tea, beer, or other suitable beverage. ♥*


## Beyond `json-file`

Alright, you can start developing (and even deploying)
with the default `json-file` driver, but at some point,
you will need something else to cope with the amount
of logs generated by your containers.

That's where the logging drivers come handy: without
changing a single line of code in your application,
you can ask your faithful container engine to send
the logs somewhere else. Neat.

Docker supports [many other logging drivers](
https://docs.docker.com/engine/admin/logging/overview/#/supported-logging-drivers),
including but not limited to:

- `awslogs`, if you're running on Amazon's cloud and don't
  plan to migrate to anything else, ever;
- `gcplogs`, if you're more a Google person;
- `syslog`, if you already have a centralized syslog
  server and want to leverage it for your containers;
- `gelf`.

I'm going to stop the list here because GELF has a few
features that make it particulary interesting *and* versatile.


## GELF

GELF stands for [Graylog Extended Log Format](http://docs.graylog.org/en/2.1/pages/gelf.html).
It was initially designed for the [Graylog] logging
system. If you haven't heard about Graylog before, it's an open source project that
pioneered "modern" logging systems like [ELK]. In fact, if you want to send
Docker logs to your ELK cluster, you will probably use the GELF protocol!
It is an open standard implemented by many logging systems (open or
proprietary).

What's so nice about the GELF protocol? It addresses some (if not most)
of the shortcomings of the syslog protocol.

With the syslog protocol, a log message is mostly a raw string, with
very little metadata.
There is some kind of agreement between syslog emitters and receivers; a *valid*
syslog message should be formatted in a specific way, allowing to extract the
following information:

- a *priority*: is this a debug message, a warning, something purely informational,
  a critical error, etc.;
- a *timestamp* indicating when the thing happened;
- a *hostname* indicating where the thing happened (i.e. on which machine);
- a *facility* indicating if the message comes from the mail system, the kernel,
  and such and such;
- a process name and number;
- etc.

That protocol was great in the 80s (and even the 90s), but it has some shortcomings:

- as it evolved over time, there are almost 10 different RFCs to specify, extend,
  and retrofit it to various use-cases;
- the message size is limited, meaning that *very long messages* (e.g.: tracebacks)
  have to be truncated or split across messages;
- at the end of the day, even if some metadata can be extracted, the payload is
  a plain, unadorned text string.

GELF made a very *risqué* move and decided that *every log message would be a dict*
(or a map or a hash or whatever you want to call them). This "dict" would have
the following fields:

- version;
- host (who sent the message in the first place);
- timestamp;
- short and long version of the message;
- *any extra field you would like!*

At first you might think, "OK, what's the deal?" but this means that when
a web servers logs a request, instead of having a raw string like this:

```
127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326
```

You get a dict like that:

```json
{
  "client": "127.0.0.1",
  "user": "frank",
  "timestamp": "2000-10-10 13:55:36 -0700",
  "method": "GET",
  "uri": "/apache_pb.gif",
  "protocol": "HTTP/1.0",
  "status": 200,
  "size": 2326
}
```

This also means that the logs get stored as structured objects, instead
of raw strings. As a result, you can make elaboarate queries (something
close to SQL) instead of carving regexes with grep like a caveperson.

OK, so GELF is a convenient format that Docker can emit, and that is
understood by a number of tools like [Graylog], [Logstash], [Fluentd],
and many more.

Moreover, you can switch from the default `json-file` to GELF very easily;
which means that you can start with `json-file` (i.e. not setup anything
in your Docker cluster), and later, when you decide that these log entries
could be useful after all, switch to GELF without changing anything in
your application, and automatically have your logs centralized and indexed
somewhere.


## Using a logging driver

How do we switch to GELF (or any other format)?

Docker provides two command-line flags for that:

- `--log-driver` to indicate which driver to use;
- `--log-opt` to pass arbitrary options to the driver.

These options can be passed to `docker run`, indicating
that you want *this one specific container* to use a different
logging mechanism; or to the Docker Engine itself (when starting
it) so that it becomes the default option for all containers.

(If you are using the Docker API to start your
containers, these options are passed to the `create` call,
within the `HostConfig.LogConfig` structure.)

The "arbitrary options" vary for each driver. In the case
of the GELF driver, you can specify [a bunch of options](
https://docs.docker.com/engine/admin/logging/overview/#/options-3)
but there is one that is mandatory: the address of the GELF receiver.

If we have a GELF receiver on the machine 1.2.3.4 on the
default UDP port 12201, you can start your container as follows:

```bash
docker run \
  --log-driver gelf --log-opt gelf-address=udp://1.2.3.4:12201 \
  alpine echo hello world
```

The following things will happen:

- the Docker Engine will pull the `alpine` image (if necessary)
- the Docker Engine will create and start our container
- the container will execute the command `echo` with arguments `hello` `world`
- the process in the container will write `hello world` to the standard output
- the `hello world` message will be passed to whomever is watching
  (i.e. you, since you started the container in the foreground)
- the `hello world` message will also be caught by Docker and sent to
  the logging driver
- the `gelf` logging driver will prepare a full GELF message, including
  the host name, the timestamp, the string `hello world`, but also a bunch
  of informations about the container, including its full ID, name,
  image name and ID, environment variables, and much more;
- this GELF message will be sent through UDP to 1.2.3.4 on port 12201.

Then, *hopefully* 1.2.3.4 receives the UDP packet, proecesses it,
writes the message to some persistent indexed store, and allows you
to retrieve or query it.

*Hopefully.*


## I would tell you an UDP [joke], but

If you have ever been on-call or responsible for other people's
code, you are probably cringing by now. Our precious logging message
is within a UDP packet that might or might not arrive to our logging server
(UDP has no transmission guarantees). If our logging server goes
away (a nice wording for "crashes horribly"), our packet might
arrive, but our message will be obliviously ignored, and we won't
know anything about it. (Technically, we might get an ICMP message
telling us that the host or port is unreachable, but at that point,
it will be too late, because we won't even know which message this
is about!)

Perhaps we can live with a few dropped messages (or a bunch,
if the logging server is being rebooted, for instance). But what if
we live in the Cloud, and our server evaporates? Seriously, though:
what if I'm sending my log messages to an EC2 instance, and for
some reason that instance has to be replaced with another one?
The new instance will have a different IP address, but my log
messages will continue to stubbornly go to the old address.


## DNS to the rescue

An easy technique to work around volatile IP addresses is
tu use DNS. Instead of specifying `1.2.3.4` as our GELF target,
we will use `gelf.container.church`, and make sure that this
points to `1.2.3.4`. That way, whenever we need to send messages
to a different machine, we just update the DNS record,
and our Docker Engine happily sends the messages to the new
machine.

Or does it?

If you have to write some code sending data to a remote machine
(say, `gelf.container.church` on port 12345), the simplest
version will look like this:

1. Resolve `gelf.container.church` to an IP address (A.B.C.D).
2. Create a socket.
3. Connect this socket to A.B.C.D, on port 12345.
4. Send data on the socket.

If you must send data multiple times, you will keep the
socket open, both for convenience and efficiency purposes.
This is particularly important with TCP sockets,
because before sending your data, you have to go through
the "3-way handshake" to establish the TCP connection;
in other words, the 3rd step in our list above is
very expensive (compared to the cost of sending a small
packet of data).

In the case of UDP sockets, you might be tempted to think:
"Ah, since I don't need to do the 3-way handshake before
sending data (the 3rd step in our list above is essentially
free), I can go through all 4 steps each time I need
to send a message!" But in fact, if you do that, you will
quickly realize that you are now stumped by the first
step, the DNS resolution. DNS resolution is less expensive than
a TCP 3-way handshake, but barely: it still requires a
round-trip to your DNS resolver.

*Aparté: yes, it is possible to have very efficient local
DNS resolvers. Something like pdns-recursor or dnsmasq
running on `localhost` will get you some craaazy fast
DNS response time for cached queries. However, if you need to make a DNS
request each time you need to send a log message, it
will add an indirect, but significant, cost to your
application, since every log line will generate not
only one syscall, but three. Damned! And some people
(like, almost everyone running on EC2) are using their
cloud provider's DNS service. These people will incur
two extra network packets for each log line.
And when the cloud
provider's DNS is down, logging will be broken. Not cool.*

Conclusion: if you log over UDP, you don't want to
resolve the logging server address each time you send
a message.


## Hmmm ... TCP to the rescue, then?

It would make sense to use a TCP connection, and keep
it up as long as we need it. If anything horrible happens
to the logging server, we can trust the TCP state machine
to detect it eventually (because timeouts and whatnots)
and notify us. When that happens, we can then re-resolve
the server name and re-connect. We just need a little bit
of extra logic in the container engine, to deal with the
unfortunate scenario where the `write` on the socket
gives us an `EPIPE` error, also known as "Broken pipe"
or in plain english "the other end is not paying attention
to us anymore."

Let's talk to our GELF server using TCP, and the problem
will be solved, right?

Right?

Unfortunately, the GELF logging driver in Docker only
supports UDP.


###  (╯°□°)╯︵ ┻━┻

At this point, if you're still with us, you might have
concluded that computing is just a specialized kind of hell,
that containers are the antichrist, and Docker is the
harbinger of doom in disguise.
 
Before drawing hasty conclusions, let's have a look at
the code.

When you create a container using the GELF driver,
[this function](https://github.com/docker/docker/blob/a33105626870bfcbca97052b25b114e005a145ac/daemon/logger/gelf/gelf.go#L43)
is invoked, and it creates a new `gelfWriter` object by
[calling `gelf.NewWriter`](
https://github.com/docker/docker/blob/a33105626870bfcbca97052b25b114e005a145ac/daemon/logger/gelf/gelf.go#L88).

Then, when the container prints something out, eventually,
[the Log function](https://github.com/docker/docker/blob/a33105626870bfcbca97052b25b114e005a145ac/daemon/logger/gelf/gelf.go#L122)
of the GELF driver is invoked. It essentially
[writes the message to the gelfWriter](
https://github.com/docker/docker/blob/a33105626870bfcbca97052b25b114e005a145ac/daemon/logger/gelf/gelf.go#L137).

This GELF writer object is implemented by an external dependency,
[github.com/Graylog2/go-gelf](https://github.com/Graylog2/go-gelf).

*Look, I see it coming, he's going to do some nasty fingerpointing
and put the blame on someone else's code. Despicable!*


## Hot potato

Let's investigate this package, in particular the
[NewWriter function](
https://github.com/Graylog2/go-gelf/blob/f80b0a83dd6533b222823ef4f649fa3acb726cf3/gelf/writer.go#L102),
the [Write method](
https://github.com/Graylog2/go-gelf/blob/f80b0a83dd6533b222823ef4f649fa3acb726cf3/gelf/writer.go#L308),
and the other methods called by the latter, [WriteMessage](
https://github.com/Graylog2/go-gelf/blob/f80b0a83dd6533b222823ef4f649fa3acb726cf3/gelf/writer.go#L199)
and [writeChunked](
https://github.com/Graylog2/go-gelf/blob/f80b0a83dd6533b222823ef4f649fa3acb726cf3/gelf/writer.go#L125).
Even if you aren't very familiar with Go, you will see that
these functions do not implement any kind of reconnection
logic. If anything bad happens, the error bubbles up to
the caller, and that's it.

If we conduct the same investigation with the code on the
Docker side (with the links in the previous section), we
reach the same conclusions. If an error occurs while sending
a log message, the error is passed to the layer above.
There is no reconnection attempt, neither in Docker's code,
nor in go-gelf's.

This, by the way, explains why Docker only supports the UDP
transport. If you want to support TCP, you have to support
more error conditions than UDP. To phrase things differently:
TCP support would be more complicated and more lines of code.


## Haters gonna hate

One possible reaction is to get angry at the brave soul who
implemented go-gelf, or the one who implemented the GELF driver
in Docker. Another better reaction is to be thankful that they
wrote that code, rather than no code at all!


## Workarounds

Let's see how to solve our logging problem.

The easiest solution is to restart our containers whenever
we need to "reconnect" (technically, resolve and reconnect).
It works, but it is very annoying.

A slightly better solution is to send logs to `127.0.0.1:12201`,
and then run a packet redirector to "bounce" or "mirror" these
packets to the actual logger; e.g.:

```bash
socat UDP-LISTEN:12201 UDP:gelf.container.church:12201
```

This needs to run on each container host. It is very lightweight,
and whenever `gelf.container.church` is updated, instead of
restarting your containers, you merely restart `socat`.

(You could also send your log packets to a virtual IP, and then
use some fancy `iptables -t nat ... -j DNAT` rules to rewrite
the destination address of the packets going to this virtual IP.)

Another option is to run Logstash on each node (instead of just
`socat`). It might seem overkill at first, but it will give
you a lot of extra flexibility with your logs: you can do
some local parsing, filtering, and even "forking," i.e.
deciding to send your logs to multiple places at the same time.
This is particularly convenient if you are switching from one
logging system to another, because it will let you feed both
systems in parallel for a while (during a transition period).

Running Logstash (or another logging tool) on each node is
also very useful if you want to be sure that you don't lose any log message,
because it would be the perfect place to insert a queue (using [Redis](
https://redislabs.com/ebook/redis-in-action/part-2-core-concepts-2/chapter-5-using-redis-for-application-support/5-1-logging-to-redis)
for simple scenarios, or [Kafka](
https://kafka.apache.org/intro) if you have stricter requirements).

Even if you end up sending your logs to a service using a
different protocol, the GELF driver is probably the easiest one
to setup to connect Docker to e.g. Logstash or Fluentd, and then
have Logstash or Fluentd speak to the logging service with
the other protocol.

UDP packets sent to `localhost` can't be lost, *except*
if the UDP socket runs out of buffer space. This could happen
if your sender (Docker) is faster than your receiver (Logstash/Fluentd),
which is why we mentioned a queue earlier: the queue will allow
the receiver to drain the UDP buffer as fast as possible to avoid
overflows. Combine that with a large enough UDP buffer, and you'll
be safe.


## Future directions

Even if running a cluster-wide `socat` is relatively easy (especially
with Swarm mode and `docker service create --mode global`), we would
rather have a good behavior out of the box.

There are already some GitHub issues related to this:
[#23679](https://github.com/docker/docker/issues/23679),
[#17904](https://github.com/docker/docker/issues/17904),
and [#16330](https://github.com/docker/docker/issues/16330).
One of the maintainers [has joined the conversation](
https://twitter.com/berndahlers/status/822508266190237698) and
there are some people at Docker Inc. who would love to see
this improved.

One possible fix is to re-resolve the GELF server name
once in a while, and when a change is detected, update
the socket destination address. Since DNS provides
TTL information, it could even be used to know how long
the IP address can be cached.

If you need better GELF support, I have good news: you can help!
I'm not going to tell you "just send us a pull request, ha ha ha!"
because I know that only a very small number of people have both
the time and expertise to do that — but if you are one of them, 
then by all means, do it! There are other ways to help, though.

First, you can monitor the GitHub issues mentioned above
([#23679](https://github.com/docker/docker/issues/23679) and
[#17904](https://github.com/docker/docker/issues/17904)).
If the contributors and maintainers ask for feedback,
indicate what would (or wouldn't) work for you. If you see
a proposition that makes sense, and you just want to say
"+1" you can do it with GitHub reactions (the "thumbs up"
emoji works perfectly for that). And if somebody proposes
a pull request, testing it will be extremely helpful and
instrmental to get it accepted.

If you look at one of these GitHub issues, you will see that
there was already a patch proposed a long time ago; but the
person who asked for the feature in the first place never tested
it, and as a result, it was never merged. Don't get me wrong,
I'm not putting the blame on that person! It's a good start to
have a GitHub issue as a kind of "meeting point" for people
needing a feature, and people who can implement it.

It's quite likely that in a few months, half of this post
will be obsolete because the GELF driver will support TCP
connections and/or correctly re-resolve addresses for UDP
addresses!


[AWS CloudWatch]: https://aws.amazon.com/cloudwatch/
[chapter on logging]: https://jpetazzo.github.io/orchestration-workshop/#logging
[ELK]: https://www.elastic.co/webinars/introduction-elk-stack
[Fluentd]: http://www.fluentd.org/
[Google Stackdriver]: https://cloud.google.com/stackdriver/
[Graylog]: https://www.graylog.org/
[Honeycomb]: https://honeycomb.io/
[Loggly]: https://www.loggly.com/
[orchestration workshop]: http://jpetazzo.github.io/orchestration-workshop/
[Splunk]: https://www.splunk.com/
[Logstash]: https://www.elastic.co/products/logstash
[joke]: http://imgur.com/gallery/kxBtzL3

