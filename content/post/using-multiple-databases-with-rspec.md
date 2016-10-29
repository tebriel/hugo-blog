+++
title = "multiple databases with rspec"
draft = false
date = "2014-10-30T15:49:44-04:00"

+++


### Issue

Unit testing a rails app with multiple databases configured per-model with `establish_connection` is unable to use advanced query features on the model objects such as `joins`.

### Background

At work, we have two databases. One is for our API (a [Tornado](http://www.tornadoweb.org/en/stable/) backend), and the other is for our UI (a [Rails](http://rubyonrails.org) frontend). Sadly, instead of separating our concerns when these two apps were built, it was decided that they should be able to just talk directly to each database. In an ideal world we'd have the Tornado API give us any details we want about its database, and endpoints in Rails to do the same for the API.

In our rails models which correspond to the Tornado's database, we have the following:

```language-ruby
class Phone < ActiveRecord::Base
  establish_connection "data_#{Rails.env}"
  # snip
end
```

What this does is tell Arel that to connect to a different database for this model, appending the current working environment to the end of the database name. Not ideal, but it works (though yields a pretty crazy `database.yml`).

Within the last two weeks, I've gotten Rails Tests up and running with some basic fixtures and about 10 tests (mostly testing that we can log in and fetch a specific page). Today I started working on testing some code I was about to change, first I decided that I should test the current functionality before I broke/refactored it.

I needed to, on-the-fly, create and query `Phone` models and correlate them with a `Phonecluster` model, so I did the following:

```language-ruby
require 'test_helper'

class SearchesControllerTest < ActionController::TestCase
  def setup
    @bad_phone_status = Phone.new({
      'cid' => '1234567890',
      'status' => 'INVALID'
    }).save()
  end
  test "Should create a phone" do
    assert @bad_phone_status
  end
end
```

Everything was hunky-dory. Looks like we're ready to go. Let's get more complicated.

`Phone` has one `Phonecluster` and their fk/pk relationship is on `cid`, so let's create two models, and try to join them together.

```language-ruby
require 'test_helper'

class SearchesControllerTest < ActionController::TestCase
  def setup
    @number = '1234567890'
    Phone.new({
      'cid' => @number,
      'status' => 'INVALID'
    }).save()
    Phonecluster.new({
      'cid' => @number,
      'cluster_id' => 1
    }).save()
  end
  
  test "Should create a phone[cluster] relationship" do
    assert_equal 1, Phone.joins(:phonecluster).length
  end
end
```

__Fail!__ If you enter into the step debugger here, and query `Phone.find_by_cid(@number)` or `Phonecluster.find_by_cid(@number)` you'll get back a model for each, what's going on here?

### Debugging The Issue

1. I stepped through the two models to see if they were calling `establish_connection`, maybe we're not instantiating the models or `Rails.env` is wrong. __Nope.__ We're running through that like normal.
1. I used the step debugger and query the models, rails returns both the `Phone` and the `Phonecluster` that were created, as I expected. `.save()` also returned `true`.
1. Last thing I tried was to look at the database while paused at a break point, aha! the records are missing!
```language-sql
mysql> SELECT count(*) FROM phones;
```
```
+----------+
| count(*) |
+----------+
|        0 |
+----------+
1 row in set (0.00 sec)
```

Well, that sucks. After a lot of messing around, the issue is that somehow the database that the model is trying to connect to is the deafult in the `database.yml`, not the one specified in `establish_connection`. It fails silently and can't do any fancy querying like `joins`, but can find the models by `cid` as they seem to be present in some weird inbetween in-memory state.

### Solution

Thankfully, it's easy (though annoying) to fix this. I just added 2 lines to my setup and all of the models now show up like I'd expect.
```language-ruby
class SearchesControllerTest < ActionController::TestCase
  def setup
    # Re-establish connection, somehow rspec lost this
    database_name = "data_#{Rails.env}"
    Phone.establish_connection database_name
    Phonecluster.establish_connection database_name
    # End re-establish connection
    
    @number = '1234567890'
    
    Phone.new({
      'cid' => @number,
      'status' => 'INVALID'
    }).save()
    
    Phonecluster.new({
      'cid' => @number,
      'cluster_id' => 1
    }).save()
    
  end
end
```
