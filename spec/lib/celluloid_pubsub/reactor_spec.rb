# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::RedisReactor do
  let(:websocket) { mock }
  let(:server) { mock }

  before(:each) do
    subject.stubs(:async).returns(subject)
    server.stubs(:debug_enabled?).returns(false)
    server.stubs(:async).returns(server)
    server.stubs(:handle_dispatched_message)
    server.stubs(:subscribers).returns({})
    server.stubs(:redis_enabled?).returns(false)
    websocket.stubs(:read)
    websocket.stubs(:url)
    websocket.stubs(:close)
    websocket.stubs(:closed?).returns(false)
    server.stubs(:alive?).returns(true)
    subject.stubs(:inspect).returns(subject)
    subject.stubs(:run)
    subject.work(websocket, server)
    subject.stubs(:unsubscribe_from_channel).returns(true)
    Celluloid::Actor.stubs(:kill).returns(true)
  end

  describe '#work' do
    it 'works ' do
      subject.expects(:run)
      subject.work(websocket, server)
      expect(subject.websocket).to eq websocket
      expect(subject.server).to eq server
      expect(subject.channels).to eq []
    end
  end

  #  describe '#rub' do
  #    let(:data) { 'some message' }
  #
  #    it 'works ' do
  #      subject.unstub(:run)
  #      websocket.stubs(:read).returns(data)
  #        subject.expects(:handle_websocket_message).with(data)
  #      subject.run
  #    end
  #  end

  describe '#parse_json_data' do
    let(:data) { 'some message' }
    let(:expected) { data.to_json }

    it 'works with hash ' do
      JSON.expects(:parse).with(data).returns(expected)
      actual = subject.parse_json_data(data)
      expect(actual).to eq expected
    end

    it 'works with exception parsing  ' do
      JSON.expects(:parse).with(data).raises(StandardError)
      actual = subject.parse_json_data(data)
      expect(actual).to eq data
    end
  end

  describe '#handle_websocket_message' do
    let(:data) { 'some message' }
    let(:json_data) { { a: 'b' } }

    it 'handle_websocket_message' do
      subject.expects(:parse_json_data).with(data).returns(json_data)
      subject.expects(:handle_parsed_websocket_message).with(json_data)
      subject.handle_websocket_message(data)
    end
  end

  describe '#handle_parsed_websocket_message' do
    it 'handle_websocket_message with a hash' do
      data = { 'client_action' => 'b' }
      data.expects(:stringify_keys).returns(data)
      subject.expects(:delegate_action).with(data)
      subject.handle_parsed_websocket_message(data)
    end

    it 'handle_websocket_message with something else than a hash' do
      data = 'some message'
      subject.expects(:handle_unknown_action).with(data)
      subject.handle_parsed_websocket_message(data)
    end
  end

  describe '#delegate_action' do
    it 'unsubscribes all' do
      data = { 'client_action' => 'unsubscribe_all' }
      subject.expects(:unsubscribe_all).returns('bla')
      subject.delegate_action(data)
    end

    it 'unsubscribes all' do
      data = { 'client_action' => 'unsubscribe', 'channel' => 'some channel' }
      subject.expects(:unsubscribe).with(data['channel'])
      subject.delegate_action(data)
    end

    it 'subscribes to channell' do
      data = { 'client_action' => 'subscribe', 'channel' => 'some channel' }
      subject.expects(:start_subscriber).with(data['channel'], data)
      subject.delegate_action(data)
    end

    it 'publish' do
      data = { 'client_action' => 'publish', 'channel' => 'some channel', 'data' => 'some data' }
      subject.expects(:publish_event).with(data['channel'], data['data'].to_json)
      subject.delegate_action(data)
    end

    it 'handles unknown' do
      data = { 'client_action' => 'some action', 'channel' => 'some channel' }
      subject.expects(:handle_unknown_action).with(data)
      subject.delegate_action(data)
    end
  end

  describe '#handle_unknown_action' do
    it 'handles unknown' do
      data = 'some data'
      server.expects(:handle_dispatched_message)
      subject.handle_unknown_action(data)
    end
  end

  describe '#unsubscribe_client' do
    let(:channel) { 'some channel' }
    it 'returns nil' do
      act = subject.unsubscribe('')
      expect(act).to eq(nil)
    end

    it 'unsubscribes' do
      subject.channels.stubs(:blank?).returns(false)
      subject.channels.expects(:delete).with(channel)
      act = subject.unsubscribe(channel)
      expect(act).to eq([])
    end

    it 'unsubscribes' do
      subject.channels.stubs(:blank?).returns(true)
      subject.websocket.expects(:close)
      act = subject.unsubscribe(channel)
      expect(act).to eq([])
    end

    it 'unsubscribes' do
      subject.channels.stubs(:blank?).returns(false)
      subject.channels.stubs(:delete)
      server.stubs(:subscribers).returns("#{channel}" => [{ reactor: subject }])
      subject.unsubscribe(channel)
      expect(server.subscribers[channel]).to eq([])
    end
  end

  describe '#shutdown' do
    it 'shutdowns' do
      subject.expects(:terminate)
      subject.shutdown
    end
  end

  describe '#start_subscriber' do
    let(:channel) { 'some channel' }
    let(:message) { { a: 'b' } }

    it 'subscribes ' do
      act = subject.start_subscriber('', message)
      expect(act).to eq(nil)
    end

    it 'subscribes ' do
      subject.stubs(:add_subscriber_to_channel).with(channel, message)
      server.stubs(:redis_enabled?).returns(false)
      subject.websocket.expects(:<<).with(message.merge('client_action' => 'successful_subscription', 'channel' => channel).to_json)
      subject.start_subscriber(channel, message)
    end

    #    it 'raises error' do
    #      subject.stubs(:add_subscriber_to_channel).raises(StandardError)
    #
    #      expect do
    #        subject.start_subscriber(channel, message)
    #      end.to raise_error(StandardError) { |e|
    #        expect(e.message).to include(channel)
    #      }
    #    end
  end

  describe '#add_subscriber_to_channel' do
    let(:channel) { 'some channel' }
    let(:message) { { a: 'b' } }
    let(:subscribers) { mock }

    it 'adds subscribed' do
      CelluloidPubsub::Registry.channels.stubs(:include?).with(channel).returns(false)
      CelluloidPubsub::Registry.channels.expects(:<<).with(channel)
      subject.expects(:channel_subscribers).with(channel).returns(subscribers)
      subscribers.expects(:push).with(reactor: subject, message: message)
      subject.add_subscriber_to_channel(channel, message)
      expect(subject.channels).to include(channel)
    end
  end

  describe '#unsubscribe_all' do
    let(:channel) { 'some channel' }
    let(:message) { { a: 'b' } }

    it 'adds subscribed' do
      CelluloidPubsub::Registry.stubs(:channels).returns([channel])
      subject.expects(:unsubscribe_from_channel).with(channel)
      subject.unsubscribe_all
    end
  end
end
