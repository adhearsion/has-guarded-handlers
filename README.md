# HasGuardedHandlers

[![Gem Version](https://badge.fury.io/rb/has-guarded-handlers.png)](https://rubygems.org/gems/has-guarded-handlers)
[![Build Status](https://secure.travis-ci.org/adhearsion/has-guarded-handlers.png?branch=develop)](http://travis-ci.org/adhearsion/has-guarded-handlers)
[![Dependency Status](https://gemnasium.com/adhearsion/has-guarded-handlers.png?travis)](https://gemnasium.com/adhearsion/has-guarded-handlers)
[![Code Climate](https://codeclimate.com/github/adhearsion/has-guarded-handlers.png)](https://codeclimate.com/github/adhearsion/has-guarded-handlers)
[![Coverage Status](https://coveralls.io/repos/adhearsion/has-guarded-handlers/badge.png?branch=develop)](https://coveralls.io/r/adhearsion/has-guarded-handlers)
[![Inline docs](http://inch-ci.org/github/adhearsion/has-guarded-handlers.png?branch=develop)](http://inch-ci.org/github/adhearsion/has-guarded-handlers)

HasGuardedHandlers allows an object's API to provide flexible handler registration, storage and matching to arbitrary events.

## Installation
    gem install has-guarded-handlers

## Usage

```ruby
require 'has_guarded_handlers'

class A
  include HasGuardedHandlers
end

a = A.new
a.register_handler :event, :type => :foo do |event|
  puts "Handled the event of type #{event.type} with value #{event.value}"
end

Event = Class.new Struct.new(:type, :value)

a.trigger_handler :event, Event.new(:foo, 'bar')
```

Register a handler for a particular named channel:

```ruby
a.register_handler(:event) { ... }
# or
a.register_handler(:event, :type => :foo) { ... }

a.trigger_handler :event, :foo
```

Register a global handler for all channels:

```ruby
a.register_handler { ... }
# or
a.register_handler(nil, :type => :foo) { ... }

a.trigger_handler :event, :foo
```

Register a temporary handler, which is deleted once triggered:

```ruby
a.register_tmp_handler(:event) { ... } # This will only fire once
a.trigger_handler :event, :foo
```

Handlers are triggered in order of priority, followed by order of declaration. By default, all handlers are registered with priority 0, and are thus executed in the order declared:

```ruby
a.register_handler { ... } # This is triggered first
a.register_handler { ... } # This is triggered second
...

a.trigger_handler :event, :foo
```

You may specify a handler priority in order to change this order. Higher priority is executed first:

```ruby
a.register_handler(:event) { ... } # This is triggered second
a.register_handler_with_priority(:event, 10) { ... } # This is triggered first
...

a.trigger_handler :event, :foo
```

You may specify a priority for a temporary handler:

```ruby
a.register_handler_with_options(:event, {:tmp => true, :priority => 10}, :foo => :bar) { ... }
```

### Handler chaining

Each handler can control whether subsequent handlers should be executed by throwing `:pass` or `:halt`.

To explicitly pass to the next handler, throw `:pass` in your handler:

```ruby
a.register_handler(:event) { do_stuff; throw :pass }
a.register_handler(:event) { ... } # This will be executed

a.trigger_handler :event, :foo
```

or indeed explicitly halt the handler chain by throwing `:halt` in the handler:

```ruby
a.register_handler(:event) { do_stuff; throw :halt }
a.register_handler(:event) { ... } # This will not be executed

a.trigger_handler :event, :foo
```

If nothing is thrown in the event handler, the handler chain will be halted by default, so subsequent handlers will not be executed.  

```ruby
a.register_handler(:event) { do_stuff; }
a.register_handler(:event) { ... } # This will not be executed

a.trigger_handler :event, :foo
```

By triggering the event in broadcast mode, the handler chain will continue by default.  

```ruby
a.register_handler(:event) { do_stuff; }
a.register_handler(:event) { ... } # This will be executed

a.trigger_handler :event, :foo, broadcast: true
```

### What are guards?

Guards are a concept borrowed from Erlang. They help to better compartmentalise handlers.

There are a number of guard types and one bit of special syntax. Guards act like AND statements. Each condition must be met if the handler is to be used.

```ruby
# Equivalent to saying (stanza.chat? && stanza.body)
message :chat?, :body
```

The different types of guards are:

```ruby
# Class / Module
#   Checks that the event is of the type specified
#   Equivalent to event.is_a? Foo
register_handler Foo

# Symbol
#   Checks for a non-false reply to calling the symbol on the event
#   Equivalent to event.chat?
register_handler :chat?

# Hash with any value (:body => 'exit')
#   Calls the key on the event and checks for equality
#   Equivalent to event.body == 'exit'
register_handler :body => 'exit'

# Hash with regular expression (:body => /exit/)
#   Calls the key on the event and checks for a match
#   Equivalent to event.body.match /exit/
register_handler :body => /exit/

# Hash with array value (:name => [:gone, :forbidden])
#   Calls the key on the event and check for inclusion in the array
#   Equivalent to [:gone, :forbidden].include?(event.name)
register_handler :name => [:gone, :fobidden]

# Hash with array key ([:[], :name] => :gone)
#   Calls the first element of the key on the event, passing the other elements as arguments
#   and checks the value matches
#   Equivalent to event[:name] == :gone
register_handler [:[], :name] => :gone

# Proc
#   Calls the proc passing in the event
#   Checks that the ID is modulo 3
register_handler proc { |m| m.id % 3 == 0 }

# Array
#   Use arrays with the previous types effectively turns the guard into
#   an OR statement.
#   Equivalent to event.body == 'foo' || event.body == 'baz'
register_handler [{:body => 'foo'}, {:body => 'baz'}]
```

## Links:
* [Source](https://github.com/adhearsion/has-guarded-handlers)
* [Documentation](http://rdoc.info/github/adhearsion/has-guarded-handlers/master/frames)
* [Bug Tracker](https://github.com/adhearsion/has-guarded-handlers/issues)

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  * If you want to have your own version, that is fine but bump version in a commit by itself so I can ignore when I pull
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2011 Ben Langfeld, Jeff Smick. MIT licence (see LICENSE.md for details).
