require 'spec_helper'

describe Travis::Notification::Publisher::Redis do
  include Support::Notifications

  let(:redis) { Redis.connect(url: Travis.config.redis.url) }
  let(:key) { "events:#{Travis.uuid}" }

  around do |example|
    Timeout.timeout(10) { example.run }
  end

  before do
    redis.del key
  end

  it 'adds to the list' do
    skip 'feature disabled at the moment'
    # redis.llen(key).should be == 0
    # publish
    # redis.llen(key).should be == 1
    # publish
    # redis.llen(key).should be == 2
  end

  it 'sets a ttl' do
    publish
    expect(redis.ttl(key)).to be <= subject.ttl
  end

  it 'encodes the payload in json' do
    skip 'feature disabled at the moment'
    # publish(foo: 'bar')
    # MultiJson.decode(redis.lindex(key, 0)).should be == {
    #   'message' => '',
    #   'uuid'    => Travis.uuid,
    #   'payload' => { 'foo' => 'bar' }
    # }
  end

  it 'queues new messages on the right' do
    skip 'feature disabled at the moment'
    # publish(x: 'foo')
    # publish(x: 'bar')
    # redis.lindex(key, 0).should include('foo')
    # redis.lindex(key, 1).should include('bar')
  end

  it 'sends out events over pubsub' do
    event = nil

    redis.subscribe(key) do |on|
      on.message do |channel, message|
        event = MultiJson.decode(message)
        redis.unsubscribe
      end

      on.subscribe { publish(foo: 'bar') }
    end

    expect(event).to eq({
      "uuid" =>    Travis.uuid,
      "event" =>   'foo.bar.instrumented',
      "message" => 'Object#instrumented:completed',
      "data" =>    { "foo" => 'bar' }
    })
  end
end
