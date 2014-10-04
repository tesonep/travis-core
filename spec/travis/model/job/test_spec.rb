require 'spec_helper'

describe Job::Test do
  include Support::ActiveRecord

  let(:job) { Factory(:test) }

  before :each do
    Travis::Event.stubs(:dispatch)
  end

  it 'is cancelable if the job has not finished yet' do
    job = Factory(:test, state: :created)
    expect(job).to be_cancelable

    job = Factory(:test, state: :started)
    expect(job).to be_cancelable
  end

  it 'is not cancelable if the job has already been finished' do
    job = Factory(:test, state: :passed)
    expect(job).not_to be_cancelable
  end

  describe 'cancelling' do
    it 'should not propagate cancel state to source' do
      build = Factory(:build, state: :started)
      build.matrix.destroy_all
      job = Factory(:test, state: :created, source: build)
      Factory(:test, state: :started, source: build)
      build.reload

      expect {
        job.cancel!
      }.to_not change { job.source.reload.state }
    end

    it 'should put a build into canceled state if all the jobs in matrix are in finished state' do
      build = Factory(:build, state: :started)
      build.matrix.destroy_all
      job = Factory(:test, state: :created, source: build)
      Job::Test::FINISHED_STATES.each do |state|
        Factory(:test, source: build, state: state)
      end
      build.reload

      expect {
      expect {
      expect {
        job.cancel!
      }.to change { build.state }
      }.to change { build.canceled_at }
      }.to change { build.repository.reload.last_build_state }

      expect(build.reload.state).to eq('canceled')
      expect(build.repository.last_build_state).to eq('canceled')
    end

    it 'should set canceled_at and finished_at on job' do
      job = Factory(:test, state: :created)

      expect {
      expect {
        job.cancel!
      }.to change { job.canceled_at }
      }.to change { job.finished_at }
    end
  end

  describe 'events' do
    describe 'start' do
      let(:data) { WORKER_PAYLOADS['job:test:start'] }

      it 'sets the state to :started' do
        job.start(data)
        expect(job.state).to eq(:started)
      end

      it 'sets the worker from the payload' do
        job.start(data)
        expect(job.worker).to eq('ruby3.worker.travis-ci.org:travis-ruby-4')
      end

      it 'resets the log content' do
        job.log.expects(:update_attributes!).with(content: '', removed_at: nil, removed_by: nil)
        job.start(data)
      end

      it 'notifies observers' do
        Travis::Event.expects(:dispatch).with('job:test:started', job, data)
        job.start(data)
      end

      it 'propagates the event to the source' do
        job.source.expects(:start)
        job.start(data)
      end

      it 'sets log\'s removed_at and removed_by to nil' do
        job.log.removed_at = Time.now
        job.log.removed_by = job.repository.owner
        job.start(data)
        expect(job.log.removed_at).to be_nil
        expect(job.log.removed_by).to be_nil
      end
    end

    describe 'finish' do
      let(:data) { WORKER_PAYLOADS['job:test:finish'] }

      it 'sets the state to the given result state' do
        job.finish(data)
        expect(job.state).to eq('passed')
      end

      it 'notifies observers' do
        Travis::Event.expects(:dispatch).with('job:test:finished', job, data)
        job.finish(data)
      end

      it 'propagates the event to the source' do
        job.source.expects(:finish).with(data)
        job.finish(data)
      end
    end

    describe 'reset' do
      let(:job) { Factory(:test, state: 'finished', queued_at: Time.now, finished_at: Time.now) }

      it 'sets the state to :created' do
        job.reset!
        expect(job.reload.state).to eq('created')
      end

      it 'resets job attributes' do
        job.reset!
        expect(job.reload.queued_at).to be_nil
        expect(job.reload.finished_at).to be_nil
      end

      it 'resets log attributes' do
        job.log.update_attributes!(content: 'foo', aggregated_at: Time.now)
        job.reset!
        expect(job.reload.log.aggregated_at).to be_nil
        expect(job.reload.log.content).to be_blank
      end

      it 'recreates log if it\'s removed' do
        job.log.destroy
        job.reload
        job.reset!
        expect(job.reload.log).not_to be_nil
      end

      xit 'clears log parts' do
      end

      it 'destroys annotations' do
        job.annotations << Factory(:annotation)
        job.reload
        job.reset!
        expect(job.reload.annotations).to be_empty
      end

      it 'triggers a :created event' do
        job.expects(:notify).with(:reset)
        job.reset
      end
    end
  end
end
