---
layout: post
title: "Securing Docker in the wild"
---

By default, the Docker API is exposed over a local UNIX socket.
If you want to control Docker from a remote host, you can configure
Docker to expose its API over a TCP socket instead. However, Docker
itself doesn't implement authentication. We will see here how we
can use SSL certificate authentication to encrypt and authenticate
the Docker API.


## The plan

This is a very simple recipe, using `socat` in front of the Docker
API. `socat` will accept HTTPS connections, make sure that the client
shows an appropriate certificate, and relay the connection to the
UNIX socket. The client should either use `socat` as well to wrap
a normal connection into a SSL connection; or use OpenSSL (or
a similar crypto library) to do the wrapping directly.


## A few words about certificates

I won't do a full intro do [public key crypto]; but the basic idea
is the following:

- the server (i.e. Docker) and each client connecting to it have
  to generate their own *private key*;
- they get a *certificate authority* to sign those keys, delivering
  them a *certificate*;
- when a client connect to the server, each party asks the other one
  to present its certificate, and is able to verify the validity
  of the certificate.

In other words: the client will know for sure that it's talking
to the server, and the server will know for sure that it's talking
to an authorized client.

In this example, we will cut corners. The client, server, and
certificate authority will actually be the *same* entity. They
will use the same key and certificate.


## Get prepared

We need to install `socat` on both the client and server; and we
need `openssl` somewhere (doesn't matter where exactly: it's purely
for generation of the key material).

```bash
apt-get install socat openssl
```

`socat` is a very common tool, so it should be available for
your distro, even if it's an exotic one.


## Generate key and certificate

Here is my quick-and-dirty recipe to generate a RSA key (stored
in `key.pem`) and a self-signed certificate (stored in `cert.pem`),
valid for 100 years:

```bash
openssl genrsa -out key.pem 2048
openssl req -new -key key.pem -x509 -out cert.pem -days 36525 -subj /CN=WoopWoop/
```

Run that anywhere, then copy both `key.pem` and `cert.pem`
on client and server.


## On server (running Docker)

Docker should run as usual. Then start `socat` like this:

```bash
socat \
  OPENSSL-LISTEN:4321,fork,reuseaddr,cert=cert.pem,cafile=cert.pem,key=key.pem \
  UNIX:/var/run/docker.sock
```

`fork` means that `socat` will fork a new child process for each incoming
connection (instead of handling only one connection and exiting right away).

`reuseaddr` is a useful socket option, so that if you exit and restart
socat, it won't tell you that the address is already taken.

By default, OPENSSL connections made with `socat` require the other end
to show a valid certificate; unless you add `verify=0`. In that case,
we want to encrypt connections *and* check certificates (to deny unauthorized
clients), so the defaults are good.


## On client (running e.g. Docker CLI)

The symmetrical invocation of `socat` looks like this:

```bash
socat \
  UNIX-LISTEN:/tmp/docker.sock,fork \
  OPENSSL:$SERVERADDR:4321,cert=cert.pem,cafile=cert.pem,key=key.pem
```

Now you can point your Docker CLI to the server through the tunnel,
like this:

```bash
docker -H unix:///tmp/docker.sock run -t -i busybox sh
```


## On client (using an HTTP client API)

If you want to connect to the Docker daemon with a regular HTTP client
(which maybe cannot connect to a UNIX socket to do HTTP requests),
try this version:

```bash
socat \
  TCP-LISTEN:4321,bind=127.0.0.1,fork \
  OPENSSL:$SERVERADDR:4321,cert=cert.pem,cafile=cert.pem,key=key.pem
```

The Docker API is then available on `http://127.0.0.1:4321`.

Enjoy!


## What's next?

It would obviously be much better to use a separate certificate authority,
and generate different keys and certificates for the server and for
each client. "This is left as an exercise for the reader," as we say! :-)


[public key crypto]: http://en.wikipedia.org/wiki/Public-key_cryptography