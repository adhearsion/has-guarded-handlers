require "has_guarded_handlers/version"
require 'securerandom'

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
    options[:priority] ||= 0
    new_handler_id.tap do |handler_id|
      guarded_handlers[type][options[:priority]] << [guards, handler, options[:tmp], handler_id]
    end
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
    delete_handler_if(type) { |g, _| g == guards }
  end

  # Trigger a handler classification with an event object
  #
  # @param [Symbol, nil] type a classification to separate handlers/events into channels
  # @param [Object] the event object to yield to the handler block
  def trigger_handler(type, event)
    return unless handler = handlers_of_type(type)
    called = false
    catch :halt do
      h = handler.find do |guards, handler, tmp|
        called = true
        val = catch(:pass) do
          if guarded?(guards, event)
            called = false
          else
            handler.call event
            true
          end
        end
        delete_handler_if(type) { |_, h, _| h.equal? handler } if tmp && val
        val
      end
    end
    !!called
  end

  private

  def delete_handler_if(type, &block) # :nodoc:
    guarded_handlers[type].each_pair do |priority, handlers|
      handlers.delete_if(&block)
    end
  end

  def handlers_of_type(type) # :nodoc:
    return unless hash = guarded_handlers[type]
    values = []
    hash.keys.sort.reverse.each do |key|
      values += hash[key]
    end
    global_handlers = guarded_handlers[nil]
    global_handlers.keys.sort.reverse.each do |key|
      values += global_handlers[key]
    end
    values
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

  def guarded_handlers # :nodoc:
    @handlers ||= Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = [] } }
  end
end
