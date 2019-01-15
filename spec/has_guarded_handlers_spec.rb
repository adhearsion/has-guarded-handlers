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
    expect(response).to receive(:call).twice.with(event)
    subject.register_handler(:event) { |e| response.call e }
    expect(subject.trigger_handler(:event, event)).to be true
    expect(subject.trigger_handler(:event, event)).to be true
  end

  it 'can register a handler for all events, regardless of category' do
    expect(response).to receive(:call).twice.with(event)
    subject.register_handler { |e| response.call e }
    subject.trigger_handler :event, event
    subject.trigger_handler :bah, event
  end

  context 'when a one-shot (tmp) handler is registered' do
    it 'can register a one-shot (tmp) handler' do
      expect(response).to receive(:call).exactly(3).times.with(event)
      expect(event).to receive(:foo).exactly(3).times.and_return :bar

      nomatch_event = double 'Event(nomatch)'
      expect(nomatch_event).to receive(:foo).twice.and_return :baz

      subject.register_handler(:event, :foo => :bar) do |e|
        response.call e
        throw :pass
      end
      subject.register_tmp_handler(:event, :foo => :bar) { |e| response.call e }

      expect(subject.trigger_handler(:event, nomatch_event)).to be false
      expect(subject.trigger_handler(:event, event)).to be true
      expect(subject.trigger_handler(:event, event)).to be true
    end

    it 'is executed once regardless of return value' do
      expect(response).to receive(:call).exactly(3).times.with(event)
      expect(event).to receive(:foo).exactly(3).times.and_return :bar

      subject.register_tmp_handler(:event, :foo => :bar) do |e|
        response.call e
        throw :pass
      end
      subject.register_tmp_handler(:event, :foo => :bar) do |e|
        response.call e
        false
      end
      subject.register_tmp_handler(:event, :foo => :bar) do |e|
        response.call e
        true
      end

      expect(subject.trigger_handler(:event, event)).to be true
      expect(subject.trigger_handler(:event, event)).to be true
      expect(subject.trigger_handler(:event, event)).to be false
    end

    it 'does not remove the handler until executed' do
      expect(response).to receive(:call).twice
      expect(event).to receive(:foo).twice.and_return :bar

      second_event = double 'Event(nomatch)'
      expect(second_event).to receive(:foo).once.and_return :baz

      subject.register_tmp_handler(:event, :foo => :bar) { |e| response.call e }
      subject.register_tmp_handler(:event, :foo => :baz) { |e| response.call e }

      expect(subject.trigger_handler(:event, event)).to be true
      expect(subject.trigger_handler(:event, event)).to be false
      expect(subject.trigger_handler(:event, second_event)).to be true
      expect(subject.trigger_handler(:event, second_event)).to be false
    end
  end

  it 'allows handlers of same type to be added/removed concurrently' do
    %w( concurrent/array concurrent/atomic/atomic_fixnum).each { |p| require p }
    Thread.abort_on_exception = true

    Event = Class.new do
      attr_reader :track, :count
      def initialize(c = 0)
        @count = Concurrent::AtomicFixnum.new(c)
        @track = Concurrent::AtomicFixnum.new
      end
      def inc_track; @track.increment > 0 end
      def cmp_count(i); @count.increment >= i end
      def dec_count; @count.decrement end
    end

    event = Event.new

    subject.register_handler :ami, [{ [:inc_track] => true }] do |e|
      sleep(0)
    end
    expect( subject.send(:guarded_handlers)[:ami][0].size ).to eql 1

    handler_id = subject.register_handler(:ami, [ [:nil?] ]) { |_| }
    expect( subject.send(:guarded_handlers)[:ami][0].size ).to eql 2

    tmp_handler_count = 3000; threads = Concurrent::Array.new
    tmp_handler_count.times do |i| # enough to reproduce concurrent regiter/unregister
      threads << Thread.new do
        h_id = subject.register_tmp_handler(:ami, [{ [:cmp_count, i] => true }]) do |e|
          e.dec_count
        end
        threads << Thread.new do
          subject.unregister_handler(:ami, h_id)
        end
        subject.trigger_handler(:ami, event)
      end
    end
    sleep(1.0)
    threads.each(&:join)

    expect( subject.trigger_handler(:ami, event) ).to be true
    expect( subject.send(:guarded_handlers)[:ami][0].size ).to eql 2

    expect( event.track.value ).to eql tmp_handler_count + 1

    subject.unregister_handler(:ami, handler_id)
    expect( subject.send(:guarded_handlers)[:ami][0].size ).to eql 1
  end

  it 'can unregister a handler after registration' do
    expect(response).to receive(:call).once.with(event)
    subject.register_handler(:event) { |e| response.call e }
    id = subject.register_handler(:event) { |e| response.call :foo }
    subject.unregister_handler :event, id
    subject.trigger_handler :event, event
  end

  it 'does not fail when no handlers are set' do
    expect(lambda do
      subject.trigger_handler :event, event
    end).to_not raise_error
    expect(subject.trigger_handler(:event, event)).to be false
  end

  it 'allows for breaking out of handlers' do
    expect(response).to receive(:handle).once
    expect(response).to receive(:fail).never
    subject.register_handler :event do |_|
      response.handle
      throw :halt
      response.fail
    end
    expect(subject.trigger_handler(:event, event)).to be true
  end

  context 'when multiple handlers are registered' do
    it "stops at the first matching handler regardless of return value" do
      expect(response).to receive(:handle).once
      subject.register_handler :event do |_|
        response.handle
        false
      end
      subject.register_handler :event do |_|
        response.handle
      end
      expect(subject.trigger_handler(:event, event)).to be true
    end

    context "and an early one raises" do
      it "raises that exception, and does not execute later handlers" do
        expect(response).to receive(:handle).never
        subject.register_handler :event do |_|
          raise "Oops"
        end
        subject.register_handler :event do |_|
          response.handle
        end
        expect { subject.trigger_handler(:event, event) }.to raise_error(StandardError, "Oops")
      end
    end

    context "when broadcast mode is enabled on trigger" do
      it "continues regardless of return value" do
        expect(response).to receive(:handle).twice
        subject.register_handler :event do |_|
          response.handle
        end
        subject.register_handler :event do |_|
          response.handle
        end
        expect(subject.trigger_handler(:event, event, broadcast: true)).to be true
      end

      context "and an early one raises" do
        it "swallows that exception, and executes later handlers" do
          expect(response).to receive(:handle).once
          subject.register_handler :event do |_|
            raise "Oops"
          end
          subject.register_handler :event do |_|
            response.handle
          end
          subject.trigger_handler(:event, event, broadcast: true)
        end

        it "can invoke a callback on an exception" do
          exception_callback = double 'Exception Callback'
          expect(exception_callback).to receive(:call).once.with(RuntimeError) do |e|
            expect(e).to be_a(RuntimeError)
            expect(e.message).to eq "Oops"
          end.ordered
          expect(response).to receive(:handle).once.ordered
          subject.register_handler :event do |_|
            raise "Oops"
          end
          subject.register_handler :event do |_|
            response.handle
          end
          subject.trigger_handler(:event, event, broadcast: true, exception_callback: exception_callback)
        end
      end
    end
  end

  it 'allows for passing to the next handler of the same type' do
    expect(response).to receive(:handle1).once
    expect(response).to receive(:handle2).once
    expect(response).to receive(:fail).never
    subject.register_handler :event do |_|
      response.handle1
      throw :pass
      response.fail
    end
    subject.register_handler :event do |_|
      response.handle2
    end
    expect(subject.trigger_handler(:event, event)).to be true
  end

  context 'when there is nothing to pass to' do
    it 'correctly indicates that a handler was called' do
      expect(response).to receive(:handle1).once
      expect(response).to receive(:fail).never
      subject.register_handler :event do |_|
        response.handle1
        throw :pass
        response.fail
      end
      expect(subject.trigger_handler(:event, event)).to be true
    end
  end

  describe 'when registering handlers with the same priority' do
    it 'preserves the order of specification of the handlers' do
      expect(response).to receive(:handle1).once.ordered
      expect(response).to receive(:handle2).once.ordered
      expect(response).to receive(:handle3).once.ordered
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
      expect(response).to receive(:handle1).once.ordered
      expect(response).to receive(:handle2).once.ordered
      expect(response).to receive(:handle3).once.ordered
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
    expect(response).to receive(:call).once

    subject.register_handler(:event) { |_| response.call }
    subject.trigger_handler :event, event

    subject.clear_handlers :event
    subject.trigger_handler :event, event
  end

  it 'can clear all handlers' do
    expect(response).to receive(:call).once

    subject.register_handler(:event) { |_| response.call }
    subject.trigger_handler :event, event

    subject.clear_handlers
    subject.trigger_handler :event, event
  end

  describe 'guards' do
    GuardMixin = Module.new
    class GuardedObject
      include GuardMixin
    end

    it 'can be a class' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, GuardedObject) { |_| response.call }

      subject.trigger_handler :event, GuardedObject.new
      subject.trigger_handler :event, Object.new
    end

    it 'can be a module' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, GuardMixin) { |_| response.call }

      subject.trigger_handler :event, GuardedObject.new
      subject.trigger_handler :event, Object.new
    end

    it 'can be a symbol' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, :chat?) { |_| response.call }

      expect(event).to receive(:chat?).and_return true
      subject.trigger_handler :event, event

      expect(event).to receive(:chat?).and_return false
      subject.trigger_handler :event, event
    end

    it 'can be a hash with string match' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, :body => 'exit') { |_| response.call }

      expect(event).to receive(:body).and_return 'exit'
      subject.trigger_handler :event, event

      expect(event).to receive(:body).and_return 'not-exit'
      subject.trigger_handler :event, event
    end

    it 'can be a hash with a value' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, :number => 0) { |_| response.call }

      expect(event).to receive(:number).and_return 0
      subject.trigger_handler :event, event

      expect(event).to receive(:number).and_return 1
      subject.trigger_handler :event, event
    end

    it 'can be a hash with a regexp' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, :body => /exit/) { |_| response.call }

      expect(event).to receive(:body).and_return 'more than just exit, but exit still'
      subject.trigger_handler :event, event

      expect(event).to receive(:body).and_return 'keyword not found'
      subject.trigger_handler :event, event

      expect(event).to receive(:body).and_return nil
      subject.trigger_handler :event, event
    end

    it 'can be a hash with arguments' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, [:[], :foo] => :bar) { |_| response.call }

      subject.trigger_handler :event, {:foo => :bar}
      subject.trigger_handler :event, {:foo => :baz}
      subject.trigger_handler :event, {}
    end

    it 'can be a hash with an array' do
      expect(response).to receive(:call).twice
      subject.register_handler(:event, :type => [:result, :error]) { |_| response.call }

      event = double 'Event'
      expect(event).to receive(:type).at_least(1).and_return :result
      subject.trigger_handler :event, event

      event = double 'Event'
      expect(event).to receive(:type).at_least(1).and_return :error
      subject.trigger_handler :event, event

      event = double 'Event'
      expect(event).to receive(:type).at_least(1).and_return :get
      subject.trigger_handler :event, event
    end

    it 'chained are treated like andand (short circuited)' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, :type => :get, :body => 'test') { |_| response.call }

      event = double 'Event'
      expect(event).to receive(:type).at_least(1).and_return :get
      expect(event).to receive(:body).and_return 'test'
      subject.trigger_handler :event, event

      event = double 'Event'
      expect(event).to receive(:type).at_least(1).and_return :set
      expect(event).to receive(:body).never
      subject.trigger_handler :event, event
    end

    it 'within an Array are treated as oror (short circuited)' do
      expect(response).to receive(:call).twice
      subject.register_handler(:event, [{:type => :get}, {:body => 'test'}]) { |_| response.call }

      event = double 'Event'
      expect(event).to receive(:type).at_least(1).and_return :set
      expect(event).to receive(:body).and_return 'test'
      subject.trigger_handler :event, event

      event = double 'Event'
      expect(event).to receive(:type).at_least(1).and_return :get
      expect(event).to receive(:body).never
      subject.trigger_handler :event, event
    end

    it 'can be a lambda' do
      expect(response).to receive(:call).once
      subject.register_handler(:event, lambda { |e| e.number % 3 == 0 }) { |_| response.call }

      expect(event).to receive(:number).once.and_return 3
      subject.trigger_handler :event, event

      expect(event).to receive(:number).once.and_return 2
      subject.trigger_handler :event, event
    end

    it 'raises an error when a bad guard is tried' do
      expect(lambda {
        subject.register_handler(:event, 0) {}
      }).to raise_error RuntimeError
    end
  end
end
