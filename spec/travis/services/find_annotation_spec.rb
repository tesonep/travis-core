require 'spec_helper'

describe Travis::Services::FindAnnotations do
  include Support::ActiveRecord

  let(:job) { Factory(:test) }
  let!(:annotation) { Factory(:annotation, job: job) }
  let(:service) { described_class.new(params) }

  attr_reader :params

  describe 'run' do
    it 'finds annotations by a given list of ids' do
      @params = { ids: [annotation.id] }
      expect(service.run).to eq([annotation])
    end

    it 'finds annotations by job_id' do
      @params = { job_id: job.id }
      expect(service.run).to eq([annotation])
    end
  end
end
