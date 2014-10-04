require 'spec_helper'

describe Travis::Services::FindRepo do
  include Support::ActiveRecord

  let!(:repo)   { Factory(:repository, :owner_name => 'travis-ci', :name => 'travis-core') }
  let(:service) { described_class.new(stub('user'), params) }

  attr_reader :params

  describe 'run' do
    it 'finds a repository by the given id' do
      @params = { :id => repo.id }
      expect(service.run).to eq(repo)
    end

    it 'finds a repository by the given owner_name and name' do
      @params = { :owner_name => repo.owner_name, :name => repo.name }
      expect(service.run).to eq(repo)
    end

    it 'does not raise if the repository could not be found' do
      @params = { :id => repo.id + 1 }
      expect { service.run }.not_to raise_error
    end
  end

  describe 'updated_at' do
    it 'returns jobs updated_at attribute' do
      @params = { :id => repo.id }
      expect(service.updated_at.to_s).to eq(repo.updated_at.to_s)
    end
  end
end
