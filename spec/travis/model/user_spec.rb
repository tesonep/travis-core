require 'spec_helper'

describe User do
  include Support::ActiveRecord

  let(:user)    { Factory(:user, :github_oauth_token => 'token') }
  let(:payload) { GITHUB_PAYLOADS[:oauth] }

  describe 'find_or_create_for_oauth' do
    def user(payload)
      User.find_or_create_for_oauth(payload)
    end

    it 'marks new users as such' do
      expect(user(payload)).to be_recently_signed_up
      expect(user(payload)).not_to be_recently_signed_up
    end

    it 'updates changed attributes' do
      expect(user(payload).attributes.slice(*GITHUB_OAUTH_DATA.keys)).to eq(GITHUB_OAUTH_DATA)
    end
  end

  describe '#to_json' do
    it 'returns JSON representation of user' do
      json = JSON.parse(user.to_json)
      expect(json['user']['login']).to eq('svenfuchs')
    end
  end

  describe 'permission?' do
    let!(:repo) { Factory(:org, :login => 'travis') }

    it 'given roles and a condition it returns true if the user has a matching permission for this role' do
      user.permissions.create!(push: true, repository_id: repo.id)
      expect(user.permission?(['push'], repository_id: repo.id)).to be_truthy
    end

    it 'given roles and a condition it returns false if the user does not have a matching permission for this role' do
      user.permissions.create!(pull: true, repository_id: repo.id)
      expect(user.permission?(['push'], repository_id: repo.id)).to be_falsey
    end

    it 'given a condition it returns true if the user has a matching permission' do
      user.permissions.create!(push: true, repository_id: repo.id)
      expect(user.permission?(repository_id: repo.id)).to be_truthy
    end

    it 'given a condition it returns true if the user has a matching permission' do
      expect(user.permission?(repository_id: repo.id)).to be_falsey
    end
  end

  describe 'organization_ids' do
    let!(:travis)  { Factory(:org, :login => 'travis') }
    let!(:sinatra) { Factory(:org, :login => 'sinatra') }

    before :each do
     user.organizations << travis
     user.save!
    end

    it 'contains the ids of organizations that the user is a member of' do
      expect(user.organization_ids).to include(travis.id)
    end

    it 'does not contain the ids of organizations that the user is not a member of' do
      expect(user.organization_ids).not_to include(sinatra.id)
    end
  end

  describe 'repository_ids' do
    let!(:travis)  { Factory(:repository, :name => 'travis', :owner => Factory(:org, :name => 'travis')) }
    let!(:sinatra) { Factory(:repository, :name => 'sinatra', :owner => Factory(:org, :name => 'sinatra')) }

    before :each do
     user.repositories << travis
     user.save!
     user.reload
    end

    it 'contains the ids of repositories the user is permitted to see' do
      expect(user.repository_ids).to include(travis.id)
    end

    it 'does not contain the ids of repositories the user is not permitted to see' do
      expect(user.repository_ids).not_to include(sinatra.id)
    end
  end

  describe 'profile_image_hash' do
    it "returns gravatar_id if it's present" do
      user.gravatar_id = '41193cdbffbf06be0cdf231b28c54b18'
      expect(user.profile_image_hash).to eq('41193cdbffbf06be0cdf231b28c54b18')
    end

    it 'returns a MD5 hash of the email if no gravatar_id and an email is set' do
      user.gravatar_id = nil
      expect(user.profile_image_hash).to eq(Digest::MD5.hexdigest(user.email))
    end

    it 'returns 32 zeros if no gravatar_id or email is set' do
      user.gravatar_id = nil
      user.email = nil
      expect(user.profile_image_hash).to eq('0' * 32)
    end
  end

  describe 'authenticate_by' do
    describe 'given a valid token and login' do
      it 'authenticates the user' do
        expect(User.authenticate_by('login' => user.login, 'token' => user.tokens.first.token)).to eq(user)
      end
    end

    describe 'given a wrong token' do
      it 'does not authenticate the user' do
        expect(User.authenticate_by('login' => 'someone-else', 'token' => user.tokens.first.token)).to be_nil
      end
    end

    describe 'given a wrong login' do
      it 'does not authenticate the user' do
        expect(User.authenticate_by('login' => user.login, 'token' => 'some-other-token')).to be_nil
      end
    end

    describe 'with encrypted token' do
      it 'authenticates the user' do
        user.tokens.first.update_column :token, 'encrypted-token'

        Travis::Model::EncryptedColumn.any_instance.stubs(:encrypt? => true, :key => 'abcd', :load => '...')
        Travis::Model::EncryptedColumn.any_instance.expects(:load).with('encrypted-token').returns('a-token')

        expect(User.authenticate_by('login' => user.login, 'token' => 'a-token')).to eq(user)
      end
    end
  end

  describe 'service_hooks' do
    let(:own_repo)   { Factory(:repository, :name => 'own-repo', :description => 'description', :active => true) }
    let(:admin_repo) { Factory(:repository, :name => 'admin-repo') }
    let(:other_repo) { Factory(:repository, :name => 'other-repo') }
    let(:push_repo) { Factory(:repository, :name => 'push-repo') }

    before :each do
      user.permissions.create! :user => user, :repository => own_repo, :admin => true
      user.permissions.create! :user => user, :repository => admin_repo, :admin => true
      user.permissions.create! :user => user, :repository => push_repo, :push => true
      other_repo
    end

    it "contains repositories where the user has an admin role" do
      expect(user.service_hooks).to include(own_repo)
    end

    it "does not contain repositories where the user does not have an admin role" do
      expect(user.service_hooks).not_to include(other_repo)
    end

    it "includes all repositories if :all options is passed" do
      hooks = user.service_hooks(:all => true)
      expect(hooks).to include(own_repo)
      expect(hooks).to include(push_repo)
      expect(hooks).to include(admin_repo)
      expect(hooks).not_to include(other_repo)
    end
  end

  describe 'track_github_scopes' do
    before { user.save! }

    it "does not resolve github scopes if the token didn't change" do
      Travis::Github.expects(:scopes_for).never
      user.save!
    end

    it "it resolves github scopes if the token did change" do
      Travis::Github.expects(:scopes_for).with(user).returns(['foo', 'bar'])
      user.github_oauth_token = 'new_token'
      user.save!
      expect(user.github_scopes).to eq(['foo', 'bar'])
    end

    it "it resolves github scopes if they haven't been resolved already" do
      Travis::Github.expects(:scopes_for).with(user).returns(['foo', 'bar'])
      user.github_scopes = nil
      user.save!
      expect(user.github_scopes).to eq(['foo', 'bar'])
    end

    it 'returns an empty list if the token is missing' do
      user.github_scopes = ['foo']
      user.github_oauth_token = nil
      expect(user.github_scopes).to be_empty
    end
  end

  describe 'correct_scopes?' do
    it "accepts correct scopes" do
      expect(user).to be_correct_scopes
    end

    it "complains about missing scopes" do
      user.github_scopes.pop
      expect(user).not_to be_correct_scopes
    end

    it "accepts additional scopes" do
      user.github_scopes << "foo"
      expect(user).to be_correct_scopes
    end
  end

  describe 'inspect' do
    context 'when user has GitHub OAuth token' do
      before :each do
        user.github_oauth_token = 'foobarbaz'
      end

      it 'does not include the user\'s GitHub OAuth token' do
        expect(user.inspect).not_to include('foobarbaz')
      end
    end

    context 'when user has no GitHub OAuth token' do
      before :each do
        user.github_oauth_token = nil
      end

      it 'indicates nil GitHub OAuth token' do
        expect(user.inspect).to include('github_oauth_token: nil')
      end
    end
  end
end
