# HasGuardedHandlers
HasGuardedHandlers allows an object's API to provide flexible handler registration, storage and matching to arbitrary events.

## Installation
    gem install has-guarded-handlers

## Usage

```ruby
require 'has_guarded_handlers'

class A
  include HasGuardedHandlers

  def receive_event(event)
    trigger_handler :event, event
  end
end

a = A.new
a.register_handler :event, :type => :foo do
  puts "Handled the event"
end

class Event
  attr_accessor :type
end

event = Event.new.tap { |e| e.type = :foo }
a.receive_event event
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

Copyright (c) 2011 Ben Langfeld, Jeff Smick. MIT licence (see LICENSE for details).
