require 'spec_helper'

describe Travis::Task do
  let(:subject) { described_class }

  describe 'run_local?' do
    after :each do
      subject.run_local = nil
      Travis::Features.redis.set('feature:travis_tasks:disabled', nil)
    end

    it 'is true by default' do
      expect(subject.run_local?).to be_truthy
    end

    it 'can be set to true manually' do
      subject.run_local = true
      expect(subject.run_local?).to be_truthy
    end

    it 'can be set to true on a child class without affecting other classes' do
      Travis::Features.enable_for_all(:travis_tasks)
      pusher = Travis::Addons::Pusher::Task
      email  = Travis::Addons::Email::Task
      pusher.run_local = true
      expect(pusher.run_local?).to be_truthy
      expect(email.run_local?).to be_falsey
      expect(subject.run_local?).to be_falsey
    end

    it 'can be set to true through a feature flag' do
      Travis::Features.deactivate_all(:travis_tasks)
      expect(subject.run_local?).to be_truthy
    end

    it 'can be set to false through a feature flag' do
      Travis::Features.enable_for_all(:travis_tasks)
      expect(subject.run_local?).to be_falsey
    end
  end
end

