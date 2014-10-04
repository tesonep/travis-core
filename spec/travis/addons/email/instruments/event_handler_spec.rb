require 'spec_helper'

describe Travis::Addons::Email::Instruments::EventHandler do
  include Travis::Testing::Stubs

  let(:build)   { stub_build(state: :failed, repository: repository, on_default_branch?: true) }
  let(:subject)   { Travis::Addons::Email::EventHandler }
  let(:publisher) { Travis::Notification::Publisher::Memory.new }
  let(:event)     { publisher.events[1] }
  let(:repository) {
    stub_repo(users: [
      stub_user(emails: [stub_email(email: 'svenfuchs@artweb-design.de')])
    ])
  }

  before :each do
    Travis::Notification.publishers.replace([publisher])
    subject.any_instance.stubs(:handle)
    subject.notify('build:finished', build)
  end

  it 'publishes a event' do
    expect(event).to publish_instrumentation_event(
      event: 'travis.addons.email.event_handler.notify:completed',
      message: 'Travis::Addons::Email::EventHandler#notify:completed (build:finished) for #<Build id=1>',
    )
    expect(event[:data].except(:payload)).to eq({
      repository: 'svenfuchs/minimal',
      request_id: 1,
      object_id: 1,
      object_type: 'Build',
      event: 'build:finished',
      recipients: ['svenfuchs@artweb-design.de'],
    })
    expect(event[:data][:payload]).not_to be_nil
  end
end

