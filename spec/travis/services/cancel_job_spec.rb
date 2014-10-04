require 'spec_helper'

describe Travis::Services::CancelJob do
  include Support::ActiveRecord

  let(:repo)    { Factory(:repository) }
  let!(:job)    { Factory(:test, repository: repo, state: :created) }
  let(:params)  { { id: job.id, source: 'tests' } }
  let(:user)    { Factory(:user) }
  let(:service) { described_class.new(user, params) }

  describe 'run' do
    it 'should cancel the job if it\'s cancelable' do
      job.stubs(:cancelable?).returns(true)
      service.stubs(:authorized?).returns(true)

      publisher = mock('publisher')
      service.stubs(:publisher).returns(publisher)
      publisher.expects(:publish).with(type: 'cancel_job', job_id: job.id, source: 'tests')

      expect {
        service.run
      }.to change { job.reload.state }

      expect(job.state).to eq('canceled')
    end

    it 'should not cancel the job if it\'s not cancelable' do
      expect(job.state).to eq(:created)
      job.stubs(:cancelable?).returns(false)

      expect {
        service.run
      }.to_not change { job.state }
    end

    it 'should not be able to cancel job if user does not have pull permission' do
      user.permissions.destroy_all

      expect(service.can_cancel?).to be_falsey
    end
  end
end

