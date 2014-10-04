require 'spec_helper'

describe Travis::Github::Services::SyncUser::Organizations::Filter do
  it 'does not allow organizations with too many repos' do
    filter = described_class.new({ 'public_repositories' => 10 }, :repositories_limit => 5)
    expect(filter.allow?).to be_falsey
  end

  it 'allows the organization if data is missing' do
    filter = described_class.new(nil)
    expect(filter.allow?).to be_truthy
  end

  it 'allows the organization if we can\'t get repositories count' do
    filter = described_class.new({'public_repositories' => nil})
    expect(filter.allow?).to be_truthy
  end
end
