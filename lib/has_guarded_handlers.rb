require "has_guarded_handlers/version"

module HasGuardedHandlers
  # Register a handler
  #
  # @param [Symbol, nil] type set the filter on a specific handler
  # @param [guards] guards take a look at the guards documentation
  # @yield [Object] stanza the incoming event
  def register_handler(type, *guards, &handler)
    register_handler_with_options type, {}, *guards, &handler
  end

  # Register a temporary handler. Once triggered, the handler will be de-registered
  #
  # @param [Symbol, nil] type set the filter on a specific handler
  # @param [guards] guards take a look at the guards documentation
  # @yield [Object] stanza the incoming event
  def register_tmp_handler(type, *guards, &handler)
    register_handler_with_options type, {:tmp => true}, *guards, &handler
  end

  # Register a handler with a specified priority
  #
  # @param [Symbol, nil] type set the filter on a specific handler
  # @param [Integer] priority the priority of the handler. Higher priority executes first
  # @param [guards] guards take a look at the guards documentation
  # @yield [Object] stanza the incoming event
  def register_handler_with_priority(type, priority, *guards, &handler)
    register_handler_with_options type, {:priority => priority}, *guards, &handler
  end

  # Register a handler with a specified set of options
  #
  # @param [Symbol, nil] type set the filter on a specific handler
  # @param [Hash] options the options for the handler
  # @option options [Integer] :priority the priority of the handler. Higher priority executes first
  # @option options [true, false] :tmp Wether or not the handler should be considered temporary (single execution)
  # @param [guards] guards take a look at the guards documentation
  # @yield [Object] stanza the incoming event
  def register_handler_with_options(type, options, *guards, &handler)
    check_guards guards
    options[:priority] ||= 0
    guarded_handlers[type][options[:priority]] << [guards, handler, options[:tmp]]
  end

  # Clear handlers with given guards
  #
  # @param [Symbol, nil] type remove filters for a specific handler
  # @param [guards] guards take a look at the guards documentation
  def clear_handlers(type, *guards)
    delete_handler_if(type) { |g, _| g == guards }
  end

  def trigger_handler(type, event)
    return unless handler = handlers_of_type(type)
    catch :halt do
      handler.find do |guards, handler, tmp|
        catch(:pass) { call_handler handler, guards, event }
        delete_handler_if(type) { |_, h, _| h.equal? handler } if tmp
      end
    end
  end

  private

  def delete_handler_if(type, &block)
    guarded_handlers[type].each_pair do |priority, handlers|
      handlers.delete_if(&block)
    end
  end

  def handlers_of_type(type)
    return unless hash = guarded_handlers[type]
    values = []
    hash.keys.sort.reverse.each do |key|
      values += hash[key]
    end
    values
  end

  def call_handler(handler, guards, event)
    handler.call event unless guarded?(guards, event)
  end

  # If any of the guards returns FALSE this returns true
  # the logic is reversed to allow short circuiting
  # (why would anyone want to loop over more values than necessary?)
  #
  # @private
  def guarded?(guards, event)
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

  def check_guards(guards)
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
    @handlers ||= Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = [] } }
  end
end
