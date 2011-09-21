require "has_guarded_handlers/version"

module HasGuardedHandlers
  def initialize(*args)
    @handlers = {}
  end

  # Register a handler
  #
  # @param [Symbol, nil] type set the filter on a specific handler
  # @param [guards] guards take a look at the guards documentation
  # @yield [Object] stanza the incoming event
  def register_handler(type, *guards, &handler)
    check_guards guards
    @handlers[type] ||= []
    @handlers[type] << [guards, handler]
  end

  # Clear handlers with given guards
  #
  # @param [Symbol, nil] type remove filters for a specific handler
  # @param [guards] guards take a look at the guards documentation
  def clear_handlers(type, *guards)
    @handlers[type].delete_if { |g, _| g == guards }
  end

  def trigger_handler(type, event)
    return unless handler = @handlers[type]
    catch :halt do
      handler.find do |guards, handler|
        catch(:pass) { call_handler handler, guards, event }
      end
    end
  end

  private

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
      when Symbol
        !event.__send__ guard
      when Array
        # return FALSE if any item is TRUE
        !guard.detect { |condition| !guarded? [condition], event }
      when Hash
        # return FALSE unless any inequality is found
        guard.find do |method, test|
          value = event.__send__(method)
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
      when Symbol, Proc, Hash, String
        nil
      else
        raise "Bad guard: #{guard.inspect}"
      end
    end
  end
end
