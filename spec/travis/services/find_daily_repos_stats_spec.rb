require 'spec_helper'
require 'travis/testing/scenario'

describe Travis::Services::FindDailyReposStats do
  include Support::ActiveRecord

  let(:service) { described_class.new(stub('user'), {}) }

  before { Scenario.default }

  it 'should include the date' do
    stats = service.run
    expect(stats.size).to eq(1)
    expect(stats.first['date']).to eq(Repository.first.created_at.to_date.to_s(:date))
  end

  it 'should include the number per day' do
    stats = service.run
    expect(stats.size).to eq(1)
    expect(stats.first['count'].to_i).to eq(2)
  end
end
