require 'spec_helper'

describe Travis::Services::FindJobs do
  include Support::ActiveRecord

  let(:repo)    { Factory(:repository) }
  let!(:job)    { Factory(:test, :repository => repo, :state => :created, :queue => 'builds.linux') }
  let(:service) { described_class.new(stub('user'), params) }

  attr_reader :params

  describe 'run' do
    it 'finds jobs on the given queue' do
      @params = { :queue => 'builds.linux' }
      expect(service.run).to include(job)
    end

    it 'does not find jobs on other queues' do
      @params = { :queue => 'builds.nodejs' }
      expect(service.run).not_to include(job)
    end

    it 'finds jobs by a given list of ids' do
      @params = { :ids => [job.id] }
      expect(service.run).to eq([job])
    end

    it 'finds jobs by state' do
      build = Factory(:build)

      Job::Test.destroy_all

      started = Factory(:test, :state => :started, :source => build)
      passed  = Factory(:test, :state => :passed,  :source => build)
      created = Factory(:test, :state => :created, :source => build)

      @params = { :state => ['created', 'passed'] }
      expect(service.run.sort_by(&:id)).to eq([created, passed].sort_by(&:id))
    end
  end

  describe 'updated_at' do
    it 'returns the latest updated_at time' do
      skip 'rack cache is disabled, so not much need for caching now'

      @params = { :queue => 'builds.linux' }
      Job.delete_all
      Factory(:test, :repository => repo, :state => :queued, :queue => 'build.common', :updated_at => Time.now - 1.hour)
      Factory(:test, :repository => repo, :state => :queued, :queue => 'build.common', :updated_at => Time.now)
      expect(service.updated_at.to_s).to eq(Time.now.to_s)
    end
  end
end
