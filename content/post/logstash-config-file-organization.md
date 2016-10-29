+++
title = "logstash config file organization"
draft = true
date = "2015-03-10T19:26:55-04:00"

+++

I'm currently at [Elastic{ON} 15](http://www.elasticon.com), which has been an amazing experience so far. Someone had the brilliant idea to set up an Apple-Style Genius bar where you just walk up and talk to someone from [Elastic](http://www.elastic.co) support. Sometimes you get contributors to the project your asking about too, it's great.

My [Logstash](http://www.logstash.net) config currently clocks in around 300 lines for the wide variety of things I have to parse out of syslog, I mentioned to [Jordan Sissel](https://twitter.com/jordansissel) that the config file was almost completely unmanageable and was killing me, and he gave me the secrets I'm about to reveal to you.

## Break your files up ##

You can break up your logstash config into multiple files, and just tell logstash to match a glob for configuration. Logstash just sorts the files alphabetically and then concatenates them together.

With the knowledge in hand that they'll just be sorted lexographically, I took my very long filter block in my config file and broke it up into 8 filter configs, like so: `0001-filter-syslog-base.conf`. The next one is `0002` and so on. If I ever have more than `9999` filters it's time to do something else. Really if I ever have more than 10, but just in case...

## Order only matters within blocks ##

For this very contrived example, let's say that my files get ordered in such a way that the config file has a filter then an output then a filter.

1. `0001-filter.conf`
1. `0002-output.conf`
1. `0003-filter.conf`

Doesn't matter! `0001` and `0003` will be ordered correctly and the output will stay outside of those two in its own output block.

This means that as long as overall, your filters and outputs have the correct order, you can have them all in separate files each in separate blocks.

Each file will begin with `filter {` or `input {` or `output {` so they could technically stand on their own, but will just be concatenated into one large config.

## Config Path uses Dir.glob ##

Oh this was the best revelation of all for me. Currently, when I'm testing things, I'll disable syslog and elasticsearch input/output and enable stdin and stdout to test patterns. Now I can just have separate files for dev and prod input and output.

Here's an example glob for launching this way:

```
bin/logstash agent -f 'config/logstash/conf.d/{dev,*filter*}.conf'
```

Here we're matching all of my filters and using the dev configuration, replace with prod and now you're pushing to ES.

For reference, here's what my directory looks like with the config files.

```
cmoultrie@Sauron ~/G/logstash-1.5.0.rc2> ls -l
0001-filter-syslog-base.conf
0002-filter-million.conf
0003-filter-prsapi.conf
0004-filter-use-multirequest.conf
0005-filter-add-query_complete.conf
0006-filter-handle-json.conf
0007-filter-set-tag.conf
0008-filter-identify-and-geohash.conf
dev.conf
prod.conf

```

## Summary ##

The real magic here is that if you have a complicated set of filters or inputs, you can just separate them into different files. The ability to, without changing the config file, run in a dev environment or production is great because I always get nervous editing the settings for those things and then pushing them back to production.

Break your files up, you'll be super happy.
