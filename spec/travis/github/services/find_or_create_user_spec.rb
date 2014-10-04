require 'spec_helper'

describe Travis::Github::Services::FindOrCreateUser do
  include Support::ActiveRecord

  let(:service) { described_class.new(nil, params) }

  attr_reader :params

  before :each do
  end

  it 'finds an existing user' do
    user = Factory(:user, login: 'foobar', github_id: 999)
    @params = { github_id: user.github_id, login: 'foobar' }
    expect(service.run).to eq(user)
  end

  it 'gets login from data if login is not available in find' do
    user = Factory(:user, login: 'foobar', github_id: 999)
    @params = { github_id: 999 }
    service.expects(:data).at_least_once.returns({ 'login' => 'foobarbaz' })

    expect(service.run).to eq(user)

    expect(user.reload.login).to eq('foobarbaz')
  end

  it 'updates repositories owner_name and nullifies other users or orgs\' login if login is changed' do
    user = Factory(:user, login: 'foobar', github_id: 999)
    user.repositories << Factory(:repository, owner_name: 'foobar', name: 'foo', owner: user)
    user.repositories << Factory(:repository, owner_name: 'foobar', name: 'bar', owner: user)

    # repository with the same owner_id, but which is of organization type
    organization = Factory(:org, id: user.id)
    ActiveRecord::Base.connection.execute("SELECT setval('organizations_id_seq', (SELECT MAX(id) FROM organizations));")
    org_repository = Factory(:repository, owner_name: 'dont_change_me', owner: organization)
    organization.repositories << org_repository

    same_login_user = Factory(:user, login: 'foobarbaz', github_id: 998)
    same_login_org  = Factory(:org, login: 'foobarbaz', github_id: 997)
    @params = { github_id: user.github_id, login: 'foobarbaz' }
    expect(service.run).to eq(user)

    expect(user.reload.repositories.map(&:owner_name).uniq).to eq(['foobarbaz'])
    expect(same_login_user.reload.login).to be_nil
    expect(same_login_org.reload.login).to be_nil
    expect(org_repository.reload.owner_name).to eq('dont_change_me')
  end

  it 'creates a user from github' do
    @params = { github_id: 999 }
    service.stubs(:fetch_data).returns({'name' => 'Foo Bar', 'login' => 'foobar', 'email' => 'foobar@example.org', 'id' => 999})
    expect {
      service.run
    }.to change { User.count }.by(1)

    user = User.first
    expect(user.name).to eq('Foo Bar')
    expect(user.login).to eq('foobar')
    expect(user.email).to eq('foobar@example.org')
    expect(user.github_id).to eq(999)
  end

  it 'creates a user from github and nullifies login if other user has the same login' do
    @params = { github_id: 999 }
    service.stubs(:fetch_data).returns({'name' => 'Foo Bar', 'login' => 'foobar', 'email' => 'foobar@example.org', 'id' => 999})

    old_user = Factory(:user, github_id: 998, login: 'foobar')
    old_org  = Factory(:org, github_id: 1000, login: 'foobar')

    new_user = nil
    expect {
      new_user = service.run
    }.to change { User.count }.by(1)

    expect(old_user.reload.login).to be_nil
    expect(old_org.reload.login).to be_nil
    expect(new_user.login).to eq('foobar')
  end

  xit 'raises a GithubApi error if the user could not be retrieved' do
  end
end
