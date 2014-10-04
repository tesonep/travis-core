require 'spec_helper'

describe Travis::Services::FindRepos do
  include Support::ActiveRecord

  let!(:repo)   { Factory(:repository, :owner_name => 'travis-ci', :name => 'travis-core') }
  let(:service) { described_class.new(stub('user'), params) }

  attr_reader :params

  it 'finds repositories by a given list of ids' do
    @params = { :ids => [repo.id] }
    expect(service.run).to eq([repo])
  end

  it 'returns the recent timeline when given empty params' do
    @params = {}
    expect(service.run).to include(repo)
  end

  it 'applies timeline only if no other params are given' do
    repo = Factory(:repository, :owner_name => 'foo', :name => 'bar', :last_build_started_at => nil)
    @params = { slug: 'foo/bar' }
    expect(service.run).to include(repo)
  end

  describe 'given a member name' do
    it 'finds a repository where that member has permissions' do
      @params = { :member => 'joshk' }
      repo.users << Factory(:user, :login => 'joshk')
      expect(service.run).to include(repo)
    end

    it 'does not find a repository where the member does not have permissions' do
      @params = { :member => 'joshk' }
      expect(service.run).not_to include(repo)
    end

    it 'does sort by latest build, putting queued (no last_build_started_at) at the front' do
      repo.update_column(:last_build_started_at, Time.now - 10)
      queued = Factory(:repository, last_build_started_at: nil)
      just_started = Factory(:repository, last_build_started_at: Time.now)

      josh = Factory(:user, :login => 'joshk')
      [repo, queued, just_started].each { |r| r.users << josh }

      @params = { :member => 'joshk' }
      expect(service.run).to eq([queued, just_started, repo])
    end
  end

  describe 'given an owner_name name' do
    it 'finds a repository with that owner_name' do
      @params = { :owner_name => 'travis-ci' }
      expect(service.run).to include(repo)
    end

    it 'does not find a repository with another owner name' do
      @params = { :owner_name => 'sinatra' }
      expect(service.run).not_to include(repo)
    end
  end

  describe 'given an owner_name name and active param' do
    it 'finds a repository with that owner_name even if it does not have any builds' do
      repo.update_column(:last_build_id, nil)
      repo.update_column(:active, true)
      @params = { :owner_name => 'travis-ci', :active => true }
      expect(service.run).to include(repo)
    end
  end

  describe 'given a slug name' do
    it 'finds a repository with that slug' do
      @params = { :slug => 'travis-ci/travis-core' }
      expect(service.run).to include(repo)
    end

    it 'does not find a repository with a different slug' do
      @params = { :slug => 'travis-ci/travis-hub' }
      expect(service.run).not_to include(repo)
    end
  end

  describe 'given a search phrase' do
    it 'finds a repository matching that phrase' do
      @params = { :search => 'travis' }
      expect(service.run).to include(repo)
    end

    it 'does not find a repository that does not match that phrase' do
      @params = { :search => 'sinatra' }
      expect(service.run).not_to include(repo)
    end
  end

  describe 'given a list of ids' do
    it 'finds included repositories' do
      @params = { :ids => [repo.id] }
      expect(service.run).to include(repo)
    end

    it 'does not find a repositories that are not included' do
      @params = { :ids => [repo.id + 1] }
      expect(service.run).not_to include(repo)
    end
  end
end
