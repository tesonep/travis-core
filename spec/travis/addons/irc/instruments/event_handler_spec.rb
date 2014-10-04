require 'spec_helper'

describe Travis::Addons::Irc::Instruments::EventHandler do
  include Travis::Testing::Stubs

  let(:subject)   { Travis::Addons::Irc::EventHandler }
  let(:publisher) { Travis::Notification::Publisher::Memory.new }
  let(:build)     { stub_build(config: { notifications: { irc: 'irc.freenode.net:1234#travis' } }) }
  let(:event)     { publisher.events[1] }

  before :each do
    Travis::Notification.publishers.replace([publisher])
    subject.any_instance.stubs(:handle)
    subject.notify('build:finished', build)
  end

  it 'publishes a event' do
    expect(event).to publish_instrumentation_event(
      event: 'travis.addons.irc.event_handler.notify:completed',
      message: 'Travis::Addons::Irc::EventHandler#notify:completed (build:finished) for #<Build id=1>',
    )
    expect(event[:data].except(:payload)).to eq({
      repository: 'svenfuchs/minimal',
      request_id: 1,
      object_id: 1,
      object_type: 'Build',
      event: 'build:finished',
      channels: ['irc.freenode.net:1234#travis']
    })
    expect(event[:data][:payload]).not_to be_nil
  end
end

