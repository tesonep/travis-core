require 'spec_helper'

describe Travis::Addons::GithubStatus::Instruments::EventHandler do
  include Travis::Testing::Stubs

  let(:subject)   { Travis::Addons::GithubStatus::EventHandler }
  let(:publisher) { Travis::Notification::Publisher::Memory.new }
  let(:event)     { publisher.events[1] }

  before :each do
    Travis.stubs(:run_service).returns(user)
    Travis::Notification.publishers.replace([publisher])
    Travis::Features.stubs(feature_deactivated?: false)
    User.stubs(with_email: nil)
    subject.any_instance.stubs(:handle)
  end

  it 'publishes a event for push events' do
    build.request.stubs(:pull_request?).returns(false)
    subject.notify('build:finished', build)

    expect(event).to publish_instrumentation_event(
      event: 'travis.addons.github_status.event_handler.notify:completed',
      message: 'Travis::Addons::GithubStatus::EventHandler#notify:completed (build:finished) for #<Build id=1>',
    )

    expect(event[:data].except(:payload)).to eq({
      repository: 'svenfuchs/minimal',
      request_id: 1,
      object_id: 1,
      object_type: 'Build',
      event: 'build:finished'
    })

    expect(event[:data][:payload]).not_to be_nil
  end

  it 'publishes a event for pull request events' do
    build.request.stubs(:pull_request?).returns(true)
    subject.notify('build:finished', build)

    expect(event).to publish_instrumentation_event(
      event: 'travis.addons.github_status.event_handler.notify:completed',
      message: 'Travis::Addons::GithubStatus::EventHandler#notify:completed (build:finished) for #<Build id=1>',
    )

    expect(event[:data].except(:payload)).to eq({
      repository: 'svenfuchs/minimal',
      request_id: 1,
      object_id: 1,
      object_type: 'Build',
      event: 'build:finished'
    })

    expect(event[:data][:payload]).not_to be_nil
  end
end
