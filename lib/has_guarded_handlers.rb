require "has_guarded_handlers/version"
require 'securerandom'
require 'concurrent/map'

#
# HasGuardedHandlers allows an object's API to provide flexible handler registration, storage and matching to arbitrary events.
#
# HasGuardedHandlers is a module that should be mixed into some object which needs to emit events.
#
# See the README for more usage info.
#
# @author Ben Langfeld <ben@langfeld.me>
#
# @example Simple usage
#
#   require 'has_guarded_handlers'
#
#   class A
#     include HasGuardedHandlers
#   end
#
#   a = A.new
#   a.register_handler :event do |event|
#     puts "Handled the event #{event.inspect}"
#   end
#
#   a.trigger_handler :event, "Foo!"
#
# @example Guarding event handlers
#
#   require 'has_guarded_handlers'
#
#   class A
#     include HasGuardedHandlers
#   end
#
#   a = A.new
#   a.register_handler :event, :type => :foo do |event|
#     puts "Handled the event of type #{event.type} with value #{event.value}"
#   end
#
#   Event = Class.new Struct.new(:type, :value)
#
#   a.trigger_handler :event, Event.new(:foo, 'bar')
#
module HasGuardedHandlers
  # Register a handler
  #
  # @param [Symbol, nil] type a classification to separate handlers/events into channels. Omitting the classification will create a handler for all events.
  # @param [guards] guards take a look at the guards documentation
  #
  # @yield [Object] trigger_object the incoming event
  #
  # @return [String] handler ID for later manipulation
  def register_handler(type = nil, *guards, &handler)
    register_handler_with_options type, {}, *guards, &handler
  end

  # Register a temporary handler. Once triggered, the handler will be de-registered
  #
  # @param [Symbol, nil] type a classification to separate handlers/events into channels Omitting the classification will create a handler for all events.
  # @param [guards] guards take a look at the guards documentation
  #
  # @yield [Object] trigger_object the incoming event
  #
  # @return [String] handler ID for later manipulation
  def register_tmp_handler(type = nil, *guards, &handler)
    register_handler_with_options type, {:tmp => true}, *guards, &handler
  end

  # Register a handler with a specified priority
  #
  # @param [Symbol, nil] type a classification to separate handlers/events into channels Omitting the classification will create a handler for all events.
  # @param [Integer] priority the priority of the handler. Higher priority executes first
  # @param [guards] guards take a look at the guards documentation
  #
  # @yield [Object] trigger_object the incoming event
  #
  # @return [String] handler ID for later manipulation
  def register_handler_with_priority(type = nil, priority = 0, *guards, &handler)
    register_handler_with_options type, {:priority => priority}, *guards, &handler
  end

  # Register a handler with a specified set of options
  #
  # @param [Symbol, nil] type a classification to separate handlers/events into channels Omitting the classification will create a handler for all events.
  # @param [Hash] options the options for the handler
  # @option options [Integer] :priority (0) the priority of the handler. Higher priority executes first
  # @option options [true, false] :tmp (false) Wether or not the handler should be considered temporary (single execution)
  # @param [guards] guards take a look at the guards documentation
  #
  # @yield [Object] trigger_object the incoming event
  #
  # @return [String] handler ID for later manipulation
  def register_handler_with_options(type = nil, options = {}, *guards, &handler)
    check_guards guards
    priority = (options[:priority] ||= 0)
    do_register_handler(type, new_handler_id, priority, guards, handler, options[:tmp])
  end

  # Unregister a handler by ID
  #
  # @param [Symbol] type the handler classification used at registration
  # @param [String] handler_id the handler ID returned by registration
  def unregister_handler(type, handler_id)
    delete_handler_if(type) { |_, _, _, id| id == handler_id }
  end

  # Clear handlers with given guards
  #
  # @param [Symbol, nil] type remove filters for a specific handler
  # @param [guards] guards take a look at the guards documentation
  def clear_handlers(type = nil, *guards)
    if type.nil?
      @handlers = nil
    else
      delete_handler_if(type) { |g, _| g == guards }
    end
  end

  # Trigger a handler classification with an event object
  #
  # @param [Symbol, nil] type a classification to separate handlers/events into channels
  # @param [Object] event the event object to yield to the handler block
  # @param [Hash] options
  # @option options [true, false] :broadcast Enables broadcast mode, where the return value or raising of handlers does not halt the handler chain. Defaults to false.
  # @option options [Proc] :exception_callback Allows handling exceptions when broadcast mode is available via a callback.
  def trigger_handler(type, event, options = {})
    return unless handler = handlers_of_type(type)
    broadcast = options[:broadcast]
    called = false
    catch :halt do
      h = handler.find do |guards, handler, tmp|
        called = true
        val = catch(:pass) do
          if guards.nil? # deleted while executing __method__
            called = nil # very special case, nothing to call
          elsif guarded?(guards, event)
            called = false
          else
            begin
              call_handler handler, guards, event
            rescue => e
              if broadcast
                options[:exception_callback].call(e) if options[:exception_callback]
              else
                raise
              end
            end
            true unless broadcast
          end
        end
        delete_handler_if(type) { |_, h, _| h.equal? handler } if tmp && called
        val
      end
    end
    called
  end

  private

  def call_handler(handler, guards, event)
    handler.call event
  end

  def do_register_handler(type, handler_id, priority, guards, handler, tmp)
    handlers_map = guarded_handlers[type]
    tuples = handlers_map[priority]
    new_tuples = (tuples.dup << [guards, handler, tmp, handler_id])
    unless handlers_map.replace_pair(priority, tuples, new_tuples)
      # try again, some one concurrently registered another handler
      do_register_handler(type, handler_id, priority, guards, handler, tmp)
    end
    handler_id
  end

  def delete_handler_if(type, &block) # :nodoc:
    handlers_map = guarded_handlers[type]
    ret = handlers_map.each_pair do |priority, tuples|
      new_tuples = tuples.dup
      cur_size = new_tuples.size
      new_tuples.delete_if(&block)
      if cur_size != new_tuples.size
        break unless handlers_map.replace_pair(priority, tuples, new_tuples)
      end
    end
    # if broke out of loop, try again (no changes made)
    return delete_handler_if(type, &block) if ret.nil?
    true
  end

  def handlers_of_type(type) # :nodoc:
    return unless handlers = guarded_handlers[type]
    values = []
    keys = handlers.keys; keys.sort!; keys.reverse!
    keys.each do |key|
      push_handler(handlers, key, values)
    end
    global_handlers = guarded_handlers[nil]
    keys = global_handlers.keys; keys.sort!; keys.reverse!
    keys.each do |key|
      push_handler(global_handlers, key, values)
    end
    values
  end

  def push_handler(handlers, key, values)
    return unless val = handlers[key] # Hash
    begin
      # to make sure on re-try elements are not added
      # twice - attempt to copy _val_ to a new array:
      val = [].push *val
      values.push *val # only here to ease testing
    rescue ThreadError # ConcurrencyError on JRuby
      return push_handler(handlers, key, values)
    end
  end

  def new_handler_id # :nodoc:
    SecureRandom.uuid
  end

  # If any of the guards returns FALSE this returns true
  # the logic is reversed to allow short circuiting
  # (why would anyone want to loop over more values than necessary?)
  #
  # @private
  def guarded?(guards, event) # :nodoc:
    guards.find do |guard|
      case guard
      when Class, Module
        !event.is_a? guard
      when Symbol
        !event.__send__ guard
      when Array
        # return FALSE if any item is TRUE
        !guard.detect { |condition| !guarded? [condition], event }
      when Hash
        # return FALSE unless any inequality is found
        guard.find do |method, test|
          value = event.__send__(*method)
          # last_match is the only method found unique to Regexp classes
          if test.class.respond_to?(:last_match)
            !(test =~ value.to_s)
          elsif test.is_a?(Array)
            !test.include? value
          else
            test != value
          end
        end
      when Proc
        !guard.call event
      end
    end
  end

  def check_guards(guards) # :nodoc:
    guards.each do |guard|
      case guard
      when Array
        guard.each { |g| check_guards [g] }
      when Class, Module, Symbol, Proc, Hash, String
        nil
      else
        raise "Bad guard: #{guard.inspect}"
      end
    end
  end

  def guarded_handlers
    @handlers ||= Concurrent::Map.new do |handlers, key|
      handlers.fetch_or_store(key, Concurrent::Map.new { |h, k| h.fetch_or_store(k, []) })
    end
  end

end
