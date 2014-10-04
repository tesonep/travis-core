require 'spec_helper'

describe Repository do
  include Support::ActiveRecord

  describe '#last_completed_build' do
    let(:repo) {  Factory(:repository, name: 'foobarbaz', builds: [build1, build2]) }
    let(:build1) { Factory(:build, finished_at: 1.hour.ago, state: :passed) }
    let(:build2) { Factory(:build, finished_at: Time.now, state: :failed) }

    before do
      build1.update_attributes(branch: 'master')
      build2.update_attributes(branch: 'development')
    end

    it 'returns last completed build' do
      expect(repo.last_completed_build).to eq(build2)
    end

    it 'returns last completed build for a branch' do
      expect(repo.last_completed_build('master')).to eq(build1)
    end
  end

  describe '#regenerate_key!' do
    it 'regenerates key' do
      repo = Factory(:repository)

      expect { repo.regenerate_key! }.to change { repo.key.private_key }
    end
  end

  describe 'associations' do
    describe 'owner' do
      let(:user) { Factory(:user) }
      let(:org)  { Factory(:org)  }

      it 'can be a user' do
        repo = Factory(:repository, owner: user)
        expect(repo.reload.owner).to eq(user)
      end

      it 'can be an organization' do
        repo = Factory(:repository, owner: org)
        expect(repo.reload.owner).to eq(org)
      end
    end
  end

  describe 'class methods' do
    describe 'find_by' do
      let(:minimal) { Factory(:repository) }

      it "should find a repository by it's github_id" do
        expect(Repository.find_by(github_id: minimal.github_id)).to eq(minimal)
      end

      it "should find a repository by it's id" do
        expect(Repository.find_by(id: minimal.id).id).to eq(minimal.id)
      end

      it "should find a repository by it's name and owner_name" do
        repo = Repository.find_by(name: minimal.name, owner_name: minimal.owner_name)
        expect(repo.owner_name).to eq(minimal.owner_name)
        expect(repo.name).to eq(minimal.name)
      end

      it "returns nil when a repository couldn't be found using params" do
        expect(Repository.find_by(name: 'emptiness')).to be_nil
      end
    end

    describe 'timeline' do
      it 'sorts the most repository with the most recent build to the top' do
        one   = Factory(:repository, name: 'one',   last_build_started_at: '2011-11-11')
        two   = Factory(:repository, name: 'two',   last_build_started_at: '2011-11-12')

        repositories = Repository.timeline.all
        expect(repositories.first.id).to eq(two.id)
        expect(repositories.last.id).to  eq(one.id)
      end
    end


    describe 'with_builds' do
      it 'gets only projects with existing builds' do
        one   = Factory(:repository, name: 'one',   last_build_started_at: '2011-11-11', last_build_id: nil)
        two   = Factory(:repository, name: 'two',   last_build_started_at: '2011-11-12', last_build_id: 101)
        three = Factory(:repository, name: 'three', last_build_started_at: nil, last_build_id: 100)

        repositories = Repository.with_builds.all
        expect(repositories.map(&:id).sort).to eq([two, three].map(&:id).sort)
      end
    end

    describe 'active' do
      let(:active)   { Factory(:repository, active: true) }
      let(:inactive) { Factory(:repository, active: false) }

      it 'contains active repositories' do
        expect(Repository.active).to include(active)
      end

      it 'does not include inactive repositories' do
        expect(Repository.active).not_to include(inactive)
      end
    end

    describe 'search' do
      before(:each) do
        Factory(:repository, name: 'repo 1', last_build_started_at: '2011-11-11')
        Factory(:repository, name: 'repo 2', last_build_started_at: '2011-11-12')
      end

      it 'performs searches case-insensitive' do
        expect(Repository.search('rEpO').to_a.count).to eq(2)
      end

      it 'performs searches with / entered' do
        expect(Repository.search('fuchs/').to_a.count).to eq(2)
      end

      it 'performs searches with \ entered' do
        expect(Repository.search('fuchs\\').to_a.count).to eq(2)
      end
    end

    describe 'by_member' do
      let(:user) { Factory(:user) }
      let(:org)  { Factory(:org) }
      let(:user_repo) { Factory(:repository, owner: user)}
      let(:org_repo)  { Factory(:repository, owner: org, name: 'globalize')}

      before do
        Permission.create!(user: user, repository: user_repo, pull: true, push: true)
        Permission.create!(user: user, repository: org_repo, pull: true)
      end

      it 'returns all repositories a user has rights to' do
        expect(Repository.by_member('svenfuchs').size).to eq(2)
      end
    end

    describe 'counts_by_owner_names' do
      let!(:repositories) do
        Factory(:repository, owner_name: 'svenfuchs', name: 'minimal')
        Factory(:repository, owner_name: 'travis-ci', name: 'travis-ci')
      end

      it 'returns repository counts per owner_name for the given owner_names' do
        counts = Repository.counts_by_owner_names(%w(svenfuchs travis-ci))
        expect(counts).to eq({ 'svenfuchs' => 1, 'travis-ci' => 1 })
      end
    end
  end

  describe 'api_url' do
    let(:repo) { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }

    before :each do
      Travis.config.github.api_url = 'https://api.github.com'
    end

    it 'returns the api url for the repository' do
      expect(repo.api_url).to eq('https://api.github.com/repos/travis-ci/travis-ci')
    end
  end

  describe 'source_url' do
    let(:repo) { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }

    it 'returns the public git source url for a public repository' do
      repo.private = false
      expect(repo.source_url).to eq('git://github.com/travis-ci/travis-ci.git')
    end

    it 'returns the private git source url for a private repository' do
      repo.private = true
      expect(repo.source_url).to eq('git@github.com:travis-ci/travis-ci.git')
    end
  end

  it "last_build returns the most recent build" do
    repo = Factory(:repository)
    attributes = { repository: repo, state: 'finished' }
    Factory(:build, attributes)
    Factory(:build, attributes)
    build = Factory(:build, attributes)

    expect(repo.last_build.id).to eq(build.id)
  end

  describe "keys" do
    let(:repo) { Factory(:repository) }

    it "should return the public key" do
      expect(repo.public_key).to eq(repo.key.public_key)
    end

    it "should create a new key when the repository is created" do
      repo = Repository.create!(owner_name: 'travis-ci', name: 'travis-ci')
      expect(repo.key).not_to be_nil
    end
  end

  describe 'branches' do
    let(:repo) { Factory(:repository) }

    it 'returns branches for the given repository' do
      %w(master production).each do |branch|
        2.times { Factory(:build, repository: repo, commit: Factory(:commit, branch: branch)) }
      end
      expect(repo.branches.sort).to eq(%w(master production))
    end

    it 'is empty for empty repository' do
      expect(repo.branches).to eql []
    end
  end

  describe 'settings' do
    let(:repo) { Factory.build(:repository) }

    it 'adds repository_id to collection records' do
      repo.save

      env_var = repo.settings.env_vars.create(name: 'FOO')
      expect(env_var.repository_id).to eq(repo.id)

      repo.settings.save

      repo.reload

      expect(repo.settings.env_vars.first.repository_id).to eq(repo.id)
    end

    it "is reset on reload" do
      repo.save

      repo.settings = {}
      repo.update_column(:settings, { 'build_pushes' => false }.to_json)
      repo.reload
      expect(repo.settings.build_pushes?).to be_falsey
      repo.update_column(:settings, { 'build_pushes' => true }.to_json)
      repo.reload
      expect(repo.settings.build_pushes?).to be_truthy
    end

    it "allows to set nil for settings" do
      repo.settings = nil
      expect(repo.settings.to_hash).to eq(Repository::Settings.new.to_hash)
    end

    it "allows to set settings as JSON string" do
      repo.settings = '{"maximum_number_of_builds": 44}'
      expect(repo.settings.to_hash).to eq(Repository::Settings.new(maximum_number_of_builds: 44).to_hash)
    end

    it "allows to set settings as a Hash" do
      repo.settings = { maximum_number_of_builds: 44}
      expect(repo.settings.to_hash).to eq(Repository::Settings.new(maximum_number_of_builds: 44).to_hash)
    end

    it 'updates settings in the DB' do
      repo.settings = {'build_pushes' => false}
      repo.save

      expect(repo.reload.settings.build_pushes?).to eq(false)

      repo.settings.merge('build_pushes' => true)
      repo.settings.save

      expect(repo.reload.settings.build_pushes?).to eq(true)
    end
  end

  describe 'last_finished_builds_by_branches' do
    let(:repo) { Factory(:repository) }

    it 'properly orders branches by last build' do
      Build.delete_all
      one = Factory(:build, repository: repo, finished_at: 2.hours.ago, state: 'finished', commit: Factory(:commit, branch: '1one'))
      two = Factory(:build, repository: repo, finished_at: 1.hours.ago, state: 'finished', commit: Factory(:commit, branch: '2two'))

      builds = repo.last_finished_builds_by_branches(1)
      expect(builds).to eq([two])
    end

    it 'retrieves last builds on all branches' do
      Build.delete_all
      old = Factory(:build, repository: repo, finished_at: 1.hour.ago,      state: 'finished', commit: Factory(:commit, branch: 'one'))
      one = Factory(:build, repository: repo, finished_at: 1.hour.from_now, state: 'finished', commit: Factory(:commit, branch: 'one'))
      two = Factory(:build, repository: repo, finished_at: 1.hour.from_now, state: 'finished', commit: Factory(:commit, branch: 'two'))
      three = Factory(:build, repository: repo, finished_at: 1.hour.from_now, state: 'finished', commit: Factory(:commit, branch: 'three'))
      three.update_attribute(:event_type, 'pull_request')

      builds = repo.last_finished_builds_by_branches
      expect(builds.size).to eq(2)
      expect(builds).to include(one)
      expect(builds).to include(two)
      expect(builds).not_to include(old)
    end
  end

  describe '#users_with_permission' do
    it 'returns users with the given permission linked to that repository' do
      repo = Factory(:repository)
      other_repo = Factory(:repository)

      user_with_permission = Factory(:user)
      user_with_permission.permissions.create!(repository: repo, admin: true)

      user_wrong_repo = Factory(:user)
      user_wrong_repo.permissions.create!(repository: other_repo, admin: true)

      user_wrong_permission = Factory(:user)
      user_wrong_permission.permissions.create!(repository: repo, push: true)

      expect(repo.users_with_permission(:admin)).to include(user_with_permission)
      expect(repo.users_with_permission(:admin)).not_to include(user_wrong_repo)
      expect(repo.users_with_permission(:admin)).not_to include(user_wrong_permission)
    end
  end
end
