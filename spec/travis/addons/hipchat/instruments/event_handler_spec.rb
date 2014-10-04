require 'spec_helper'

describe Travis::Addons::Hipchat::Instruments::EventHandler do
  include Travis::Testing::Stubs

  let(:subject)   { Travis::Addons::Hipchat::EventHandler }
  let(:publisher) { Travis::Notification::Publisher::Memory.new }
  let(:build)     { stub_build(config: { notifications: { hipchat: 'hipchat_room' } }) }
  let(:event)     { publisher.events[1] }

  before :each do
    Travis::Notification.publishers.replace([publisher])
    subject.any_instance.stubs(:handle)
    subject.notify('build:finished', build)
  end

  it 'publishes a event' do
    expect(event).to publish_instrumentation_event(
      event: 'travis.addons.hipchat.event_handler.notify:completed',
      message: 'Travis::Addons::Hipchat::EventHandler#notify:completed (build:finished) for #<Build id=1>',
    )
    expect(event[:data].except(:payload)).to eq({
      event: 'build:finished',
      targets: ['hipchat_room'],
      repository: 'svenfuchs/minimal',
      request_id: 1,
      object_id: 1,
      object_type: 'Build'
    })
    expect(event[:data][:payload]).not_to be_nil
  end
end

