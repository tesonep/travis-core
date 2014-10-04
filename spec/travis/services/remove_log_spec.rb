require 'spec_helper'

describe Travis::Services::RemoveLog do
  include Support::ActiveRecord

  let(:repo)    { Factory(:repository) }
  let(:job)     { Factory(:test, repository: repo, state: :created) }
  let(:user)    { Factory(:user) }
  let(:service) { described_class.new(user, params) }
  let(:params)  { { id: job.id, reason: 'Because reason!'} }

  context 'when job is not finished' do
    before :each do
      job.stubs(:finished?).returns false
      user.stubs(:permission?).with(:push, anything).returns true
    end

    it 'raises JobUnfinished error' do
      expect {
        service.run
      }.to raise_error Travis::JobUnfinished
    end
  end

  context 'when user does not have push permissions' do
    before :each do
      user.stubs(:permission?).with(:push, anything).returns false
    end

    it 'raises AuthorizationDenied' do
      expect {
        service.run
      }.to raise_error Travis::AuthorizationDenied
    end
  end

  context 'when a job is found' do
    before do
      find_by_id = stub
      find_by_id.stubs(:find_by_id).returns job
      job.stubs(:finished?).returns true
      service.stubs(:scope).returns find_by_id
      user.stubs(:permission?).with(:push, anything).returns true
    end

    it 'runs successfully' do
      result = service.run
      expect(result.removed_by).to eq(user)
      expect(result.removed_at).to be_truthy
      expect(result).to be_truthy
    end


    it "updates logs with desired information" do
      service.run
      expect(service.log.content).to match(Regexp.new(user.name))
      expect(service.log.content).to match(Regexp.new(params[:reason]))
    end

    context 'when log is already removed' do
      it 'raises LogAlreadyRemoved error' do
        service.run
        expect {
          service.run
        }.to raise_error Travis::LogAlreadyRemoved
      end
    end
  end

  context 'when a job is not found' do
    before :each do
      find_by_id = stub
      find_by_id.stubs(:find_by_id).raises(ActiveRecord::SubclassNotFound)
      service.stubs(:scope).returns(find_by_id)
    end

    it 'raises ActiveRecord::RecordNotFound exception' do
      expect { service.run }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

end

describe Travis::Services::RemoveLog::Instrument do
  include Support::ActiveRecord

  let(:service)   { Travis::Services::RemoveLog.new(user, params) }
  let(:repo)      { Factory(:repository) }
  let(:user)      { Factory(:user) }
  let(:job)       { Factory(:test, repository: repo, state: :passed) }
  let(:params)    { { id: job.id, reason: 'Because Science!' } }
  let(:publisher) { Travis::Notification::Publisher::Memory.new }
  let(:event)     { publisher.events.last }

  before :each do
    Travis::Notification.publishers.replace([publisher])
    service.stubs(:run_service)
    user.stubs(:permission?).with(:push, anything).returns true
  end

  it 'publishes a event' do
    service.run
    expect(event).to publish_instrumentation_event(
      event: 'travis.services.remove_log.run:completed',
      message: "Travis::Services::RemoveLog#run:completed for <Job id=#{job.id}> (svenfuchs)",
    )
  end
end
