require 'spec_helper'

describe HasGuardedHandlers do
  subject do
    Object.new.tap do |o|
      o.extend HasGuardedHandlers
    end
  end

  let(:event) { double 'Event' }
  let(:response) { double 'Response' }

  it 'can register a handler' do
    response.should_receive(:call).twice.with(event)
    subject.register_handler(:event) { |e| response.call e }
    subject.trigger_handler(:event, event).should be_true
    subject.trigger_handler(:event, event).should be_true
  end

  it 'can register a handler for all events, regardless of category' do
    response.should_receive(:call).twice.with(event)
    subject.register_handler { |e| response.call e }
    subject.trigger_handler :event, event
    subject.trigger_handler :bah, event
  end

  it 'can register a one-shot (tmp) handler' do
    response.should_receive(:call).exactly(3).times.with(event)
    event.should_receive(:foo).exactly(3).times.and_return :bar

    nomatch_event = double 'Event(nomatch)'
    nomatch_event.should_receive(:foo).twice.and_return :baz

    subject.register_handler(:event, :foo => :bar) do |e|
      response.call e
      throw :pass
    end
    subject.register_tmp_handler(:event, :foo => :bar) { |e| response.call e }

    subject.trigger_handler(:event, nomatch_event).should be_false
    subject.trigger_handler(:event, event).should be_true
    subject.trigger_handler(:event, event).should be_true
  end

  it 'can unregister a handler after registration' do
    response.should_receive(:call).once.with(event)
    subject.register_handler(:event) { |e| response.call e }
    id = subject.register_handler(:event) { |e| response.call :foo }
    subject.unregister_handler :event, id
    subject.trigger_handler :event, event
  end

  it 'does not fail when no handlers are set' do
    lambda do
      subject.trigger_handler :event, event
    end.should_not raise_error
    subject.trigger_handler(:event, event).should be_false
  end

  it 'allows for breaking out of handlers' do
    response.should_receive(:handle).once
    response.should_receive(:fail).never
    subject.register_handler :event do |_|
      response.handle
      throw :halt
      response.fail
    end
    subject.trigger_handler(:event, event).should be_true
  end

  context 'when multiple handlers are registered' do
    it "stops at the first matching handler regardless of return value" do
      response.should_receive(:handle).once
      subject.register_handler :event do |_|
        response.handle
        false
      end
      subject.register_handler :event do |_|
        response.handle
      end
      subject.trigger_handler(:event, event).should be_true
    end
  end

  it 'allows for passing to the next handler of the same type' do
    response.should_receive(:handle1).once
    response.should_receive(:handle2).once
    response.should_receive(:fail).never
    subject.register_handler :event do |_|
      response.handle1
      throw :pass
      response.fail
    end
    subject.register_handler :event do |_|
      response.handle2
    end
    subject.trigger_handler(:event, event).should be_true
  end

  context 'when there is nothing to pass to' do
    it 'correctly indicates that a handler was called' do
      response.should_receive(:handle1).once
      response.should_receive(:fail).never
      subject.register_handler :event do |_|
        response.handle1
        throw :pass
        response.fail
      end
      subject.trigger_handler(:event, event).should be_true
    end
  end

  describe 'when registering handlers with the same priority' do
    it 'preserves the order of specification of the handlers' do
      response.should_receive(:handle1).once.ordered
      response.should_receive(:handle2).once.ordered
      response.should_receive(:handle3).once.ordered
      subject.register_handler :event do |_|
        response.handle1
        throw :pass
      end
      subject.register_handler :event do |_|
        response.handle2
        throw :pass
      end
      subject.register_handler :event do |_|
        response.handle3
        throw :pass
      end
      subject.trigger_handler :event, event
    end
  end

  describe 'when registering handlers with a specified priority' do
    it 'executes handlers in that order' do
      response.should_receive(:handle1).once.ordered
      response.should_receive(:handle2).once.ordered
      response.should_receive(:handle3).once.ordered
      subject.register_handler_with_priority :event, -10 do |_|
        response.handle3
        throw :pass
      end
      subject.register_handler_with_priority :event, 0 do |_|
        response.handle2
        throw :pass
      end
      subject.register_handler_with_priority :event, 10 do |_|
        response.handle1
        throw :pass
      end
      subject.trigger_handler :event, event
    end
  end

  it 'can clear handlers' do
    response.should_receive(:call).once

    subject.register_handler(:event) { |_| response.call }
    subject.trigger_handler :event, event

    subject.clear_handlers :event
    subject.trigger_handler :event, event
  end

  describe 'guards' do
    GuardMixin = Module.new
    class GuardedObject
      include GuardMixin
    end

    it 'can be a class' do
      response.should_receive(:call).once
      subject.register_handler(:event, GuardedObject) { |_| response.call }

      subject.trigger_handler :event, GuardedObject.new
      subject.trigger_handler :event, Object.new
    end

    it 'can be a module' do
      response.should_receive(:call).once
      subject.register_handler(:event, GuardMixin) { |_| response.call }

      subject.trigger_handler :event, GuardedObject.new
      subject.trigger_handler :event, Object.new
    end

    it 'can be a symbol' do
      response.should_receive(:call).once
      subject.register_handler(:event, :chat?) { |_| response.call }

      event.should_receive(:chat?).and_return true
      subject.trigger_handler :event, event

      event.should_receive(:chat?).and_return false
      subject.trigger_handler :event, event
    end

    it 'can be a hash with string match' do
      response.should_receive(:call).once
      subject.register_handler(:event, :body => 'exit') { |_| response.call }

      event.should_receive(:body).and_return 'exit'
      subject.trigger_handler :event, event

      event.should_receive(:body).and_return 'not-exit'
      subject.trigger_handler :event, event
    end

    it 'can be a hash with a value' do
      response.should_receive(:call).once
      subject.register_handler(:event, :number => 0) { |_| response.call }

      event.should_receive(:number).and_return 0
      subject.trigger_handler :event, event

      event.should_receive(:number).and_return 1
      subject.trigger_handler :event, event
    end

    it 'can be a hash with a regexp' do
      response.should_receive(:call).once
      subject.register_handler(:event, :body => /exit/) { |_| response.call }

      event.should_receive(:body).and_return 'more than just exit, but exit still'
      subject.trigger_handler :event, event

      event.should_receive(:body).and_return 'keyword not found'
      subject.trigger_handler :event, event

      event.should_receive(:body).and_return nil
      subject.trigger_handler :event, event
    end

    it 'can be a hash with arguments' do
      response.should_receive(:call).once
      subject.register_handler(:event, [:[], :foo] => :bar) { |_| response.call }

      subject.trigger_handler :event, {:foo => :bar}
      subject.trigger_handler :event, {:foo => :baz}
      subject.trigger_handler :event, {}
    end

    it 'can be a hash with an array' do
      response.should_receive(:call).twice
      subject.register_handler(:event, :type => [:result, :error]) { |_| response.call }

      event = double 'Event'
      event.should_receive(:type).at_least(1).and_return :result
      subject.trigger_handler :event, event

      event = double 'Event'
      event.should_receive(:type).at_least(1).and_return :error
      subject.trigger_handler :event, event

      event = double 'Event'
      event.should_receive(:type).at_least(1).and_return :get
      subject.trigger_handler :event, event
    end

    it 'chained are treated like andand (short circuited)' do
      response.should_receive(:call).once
      subject.register_handler(:event, :type => :get, :body => 'test') { |_| response.call }

      event = double 'Event'
      event.should_receive(:type).at_least(1).and_return :get
      event.should_receive(:body).and_return 'test'
      subject.trigger_handler :event, event

      event = double 'Event'
      event.should_receive(:type).at_least(1).and_return :set
      event.should_receive(:body).never
      subject.trigger_handler :event, event
    end

    it 'within an Array are treated as oror (short circuited)' do
      response.should_receive(:call).twice
      subject.register_handler(:event, [{:type => :get}, {:body => 'test'}]) { |_| response.call }

      event = double 'Event'
      event.should_receive(:type).at_least(1).and_return :set
      event.should_receive(:body).and_return 'test'
      subject.trigger_handler :event, event

      event = double 'Event'
      event.should_receive(:type).at_least(1).and_return :get
      event.should_receive(:body).never
      subject.trigger_handler :event, event
    end

    it 'can be a lambda' do
      response.should_receive(:call).once
      subject.register_handler(:event, lambda { |e| e.number % 3 == 0 }) { |_| response.call }

      event.should_receive(:number).once.and_return 3
      subject.trigger_handler :event, event

      event.should_receive(:number).once.and_return 2
      subject.trigger_handler :event, event
    end

    it 'raises an error when a bad guard is tried' do
      lambda {
        subject.register_handler(:event, 0) {}
      }.should raise_error RuntimeError
    end
  end
end
