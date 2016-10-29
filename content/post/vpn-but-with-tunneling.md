+++
title = "vpn but with tunneling"
draft = true
date = "2015-02-26T23:18:37-04:00"

+++

## Background ##
I work at a mid-aged startup, [PindropSecurity](http://pindropsecurity.com), and all of our internal resources such as [Github Enterprise](https://enterprise.github.com), [Jira](https://www.atlassian.com/software/jira), [Jenkins](http://jenkins-ci.org), etc (I could keep going, but there's no point) are things I have become accustomed to having, and don't really want to live without when I'm working from home, for example: when Atlanta decides to shut down over the potential of snow.

## Problem ##
Engineering and our list of internal resources is growing faster than our OPS team would like and because we deal with some sensitive data, we're still working out all the details of our VPN solution. So while we wait on that to arrive, how do I get access to everything I need?

## First Solution Attempt ##

Well, normally you do something like use [sshuttle](https://github.com/apenwarr/sshuttle) but if you're like me, and running Yosemite, that's no longer an option.

Okay, sure, let's create a reverse tunnel for every site I want to access.

```
ssh -f -L 8080:jira.internal:80 remote-host -N
ssh -f -L 8081:github.internal:80 remote-host -N
ssh -f -L 8082:jenkins.internal:80 remote-host -N
```

Okay, now I just need to access those in my browser, let's navigate to http://127.0.0.1:8080, then http://127.0.0.1:8081, then http://127.0.0.1:8082. Wait, which one is which?

At this point, I actually took the time to spin up an [nginx](http://nginx.org) server, edited my hosts file for each of these, then had nginx proxy them to the proper ports. All of this was getting very, very complicated and plus I was running nginx locally to handle my web traffic.

## There's a better way! ##

SOCKS Proxy is the way to go, just create a tunnel on an arbitrary port, say 5000 like so the following, and you're already halfway there.
```
ssh remote-host -N -D 5000
```

Now, open up System Preferences | Network | Advanced | Proxies and check the SOCKS Proxy box, set the host : port to `127.0.0.1 : 5000`.

A lot of our internal resources either end in .net or .local, so to make sure those always flow through the tunnel, I set these as my only hosts that bypass the proxy: `169.254/16, *.com, *.org`. Your network setup may differ from mine. I specifically excluded .com so that I wouldn't stream Spotify through the work connection, and .org just seemed like a good idea.

Save and apply those settings, and now you can navigate to those internal resources like you do when you're wired up at work.

## But wait, there's more. ##

Okay, that's cool and all, but I want to push to our internal Enterprise Github, how do I do that, Mr. Smartypants?

Well, [@brimston3](https://twitter.com/brimston3) our local OPSMaster shared this super awesome ProxyCommand for your .ssh config (`~/.ssh/config`) to allow you to work internal and remote with the same configuration.

```
Host github.internal
    HostName github.internal
    IdentityFile /Users/cmoultrie/.ssh/id_rsa
    ProxyCommand bash -c 'nc -w 15 %h %p; ssh remote-host -W %h:%p'
    User git
```

Assuming that you cloned from `github.internal`, this allows you use netcat to try to hit the server locally first, then tunnel into your network if that fails. It works like a charm.

## One More Thing ##

We just spun up [HipChat Server](https://www.hipchat.com/server) Internally (we're soon going to have every service available from every company internally installed, maybe we'll get our own stackoverflow preopulated with questions/answers too) and I couldn't find any documentation on what ports it needed to use to get to the mothership and it wasn't using the system's SOCKS proxy settings.

So, I spun up [Wireshark](https://www.wireshark.org) and just watched it trying to connect, inspected the port (5222) and then set up a second tunnel like so:

`ssh -L 5222:hipchat.internal:5222 remote-host -N`

I edited the connection settings in the hipchat app to talk to `127.0.0.1` and now have remote chat as well!

### Done ###

So there you have it, simple way to get into your work network if you don't have a VPN solution, so that you can continue to be productive, or just send your co-workers [cat memes](http://41.media.tumblr.com/tumblr_m0jfy81TTT1qb6t6wo1_500.jpg), whatever works for you.
