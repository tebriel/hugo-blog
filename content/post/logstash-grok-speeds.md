+++
title = "logstash grok speeds"
draft = false
date = "2014-12-21T15:56:53-04:00"

+++

Logstash and its Grok filter are excellent and I love them, but it was going so slow that the data was useless by the time I had finally ingested it to review it, here's what was wrong and how I fixed it.

### Issue

The Grok filter in [Logstash](http://www.logstash.net) was only able to handle between 10 and 30 log lines per second based on my many REGEX lines. This is slower than the speed at which we generate log lines (~50/sec). 

### Background

At [Pindrop](http://www.pindropsecurity.com) we send all log messages to Syslog for aggregation. This means that all logs for all purposes are in the same file. I set up an [ELK](http://www.elasticsearch.org/overview/elkdownloads/) Stack on my laptop to:

*  Get deeper insight into what kinds of response times our customers should be expecting
*  Determine where we were spending the most time in generating our API response
*  Look for anomalies, similarities, and other interesting points in what customers are querying for.

The grok filter config was immediately very complicated, due to the widely varying nature of our log lines, mixture of appliations sending log lines, and the detail I needed to pluck from these lines. For example, some of our log lines have a Python array pretty printed, whereas others did a JSON serialization of the data. Extracting phone numbers and usernames from this data is a dizzying set of REGEX queries.

Thankfully to develop these grok lines, [Grok Debugger](https://grokdebug.herokuapp.com) exists, which will save your sanity.

Here's an example log line:

`Dec 18 07:49:05 box-004 MainProcess[36381]: pindrop.profiler INFO [req bdcecd58a4ab7c2e@box-004] fetch_data - finished at 1418888945.046632, taking 0.006296 seconds (0.00 cpu)`

This is one of the easier examples, the data I want from this line is:

*  Timestamp (`Dec 18 07:49:05`)
*  Who logged it? (`pindrop.profiler`)
*  Function (`fetch_data`)
*  How long did it take? (`0.006296`)

So I have a grok configuration that looks like this:

```language-ruby
filter {
    grok {
        match => ["message", "%{pd_SYSLOG_NORMAL} %{pd_REQUEST} %{DATA:proc_detail} - %{DATA}, taking %{NUMBER:duration_seconds:float} seconds"]
        patterns_dir => "patterns/"
    }
}
```

I also have all these reusable patterns that I wrote/modified from the Logstash base.

```
pd_UNIQUE_ID [a-f0-9]{12,16}

pd_SOMECLASS (?:[a-zA-Z0-9-_]+[.]?)+[A-Za-z0-9$_]+

pd_SYSLOG_BASE %{SYSLOGTIMESTAMP:timestamp} %{HOST} %{SYSLOGPROG}:
pd_SYSLOG_NORMAL %{pd_SYSLOG_BASE} %{pd_SOMECLASS} (INFO|ERROR|WARN)
pd_REQUEST \[req %{pd_UNIQUE_ID:unique_id}@%{HOST}\]
```

This is a pretty specific pattern, I realize. But with our many different types of loglines, it's hard to be more generic, capture all the data I need, and be able to come in and edit them again later and maintain my sanity (which is already wearing thin).

### Debugging the Problem

I knew that since I had about 15 different styles of patterns all in sequence from most-specific to least (with `break_on_match => true`) that testing each of these in sequence was going to be the biggest time-sink. I optimized and limited these patterns as much as I could, but with little success.

I dove into Logstash's [Grok Filter](https://github.com/elasticsearch/logstash/blob/1.4/lib/logstash/filters/grok.rb) and started timing the regex match, like so:

```language-ruby
now = Time.now
grok, match = grok.match(input.to_s) # Original Line
total = Time.now - now
if total > @average_time
    @logger.warn("Took #{total}s which is #{total - @average_time} longer than average of #{@average_time}", :event => input)
    @average_time = (@average_time + total) / 2
end
```

This gave me some good insight

1.  What the average time spent handling these patterns was.
1.  If our patterns were taking progressively longer over time.
1.  Which input lines were taking longer than the average to process.

My longest offenders were taking 1.5s, where the quick ones were less than 0.01s.

### Solution

In the end, I knew that simplifying the many patterns we would inevitably test these log lines against was the only thing that was going to make a difference. As I was scouring the Logstash Docs, I noticed that there was this section on [overwriting](http://logstash.net/docs/1.4.2/filters/grok#overwrite) a field with a match from a grok line.

This gave me a 'eureka' moment in which I realized I should match the Syslog base of the line once and only once, and then in a separate grok filter, match my speciality parts. Now my grok line is just:

```language-ruby
match => ["message", "%{pd_REQUEST} %{DATA:proc_detail} - %{DATA}, taking %{NUMBER:duration_seconds:float} seconds"]
```

`pd_SYSLOG_NORMAL` actually expands into 5 different patterns. The result of removing this is that I now only have 5 patterns left in the match line (`pd_REQUEST` is 2). A 50% decrease in patterns for just this one line, but more than that, in the worst case a line was running on those initial 5 patterns 15x. So this means I take 70 matching patterns out of the mix (assuming that 1 of those has to match).

The speed up was dramatic, I went from matching 10-30 lines/s to 500 lines/s. So, if you're trying to match on the same thing over and over again, pull it out into a separate grok filter, it will save you time and sanity.
