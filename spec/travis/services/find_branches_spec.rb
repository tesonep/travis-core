require 'spec_helper'

describe Travis::Services::FindBranches do
  include Support::ActiveRecord

  let(:repo)    { Factory(:repository, :owner_name => 'travis-ci', :name => 'travis-core') }
  let!(:build)  { Factory(:build, :repository => repo, :state => :finished) }
  let(:service) { described_class.new(stub('user'), params) }

  attr_reader :params

  it 'finds the last builds of the given repository grouped per branch' do
    @params = { :repository_id => repo.id }
    expect(service.run).to include(build)
  end

  it 'scopes to the given repository' do
    @params = { :repository_id => repo.id }
    build = Factory(:build, :repository => Factory(:repository), :state => :finished)
    expect(service.run).not_to include(build)
  end

  it 'returns an empty build scope when the repository could not be found' do
    @params = { :repository_id => repo.id + 1 }
    expect(service.run).to eq(Build.none)
  end

  it 'finds branches by a given list of ids' do
    @params = { :ids => [build.id] }
    expect(service.run).to eq([build])
  end
end
