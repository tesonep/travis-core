require 'spec_helper'

describe Request do
  include Support::ActiveRecord

  let(:repo)    { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }
  let(:commit)  { Commit.new(commit: '12345678') }
  let(:request) { Request.new(repository: repo, commit: commit) }

  describe 'config_url' do
    it 'returns the raw url to the .travis.yml file on github' do
      expect(request.config_url).to eq('https://api.github.com/repos/travis-ci/travis-ci/contents/.travis.yml?ref=12345678')
    end
  end

  describe 'pull_request_title' do
    it 'returns the title of the pull request from payload' do
      request.event_type = 'pull_request'
      request.payload = { 'pull_request' => { 'title' => 'A pull request' } }

      expect(request.pull_request_title).to eq('A pull request')
    end

    it 'returns nil for non pull request' do
      request.event_type = 'build'
      request.payload = { 'pull_request' => { 'title' => 'A pull request' } }

      expect(request.pull_request_title).to be_nil
    end
  end

  describe 'tag_name' do
    it 'returns a tag name if available' do
      request.payload = { 'ref' => 'refs/tags/foo' }

      expect(request.tag_name).to eq('foo')
    end

    it 'returns nil if a tag name is not available' do
      request.payload = { 'ref' => 'refs/heads/foo' }

      expect(request.tag_name).to be_nil
    end
  end

  describe 'branch_name' do
    it 'returns a branch name if available' do
      request.payload = { 'ref' => 'refs/heads/foo' }

      expect(request.branch_name).to eq('foo')
    end

    it 'returns nil if a branch name is not available' do
      request.payload = { 'ref' => 'refs/tags/foo' }

      expect(request.branch_name).to be_nil
    end
  end

  describe 'same_repo_pull_request?' do
    it 'returns true if the base and head repos match' do
      request.payload = {
        'pull_request' => {
          'base' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' } },
          'head' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' } }
        }
      }

      expect(request.same_repo_pull_request?).to be_truthy
    end

    it 'returns false if the base and head repos do not match' do
      request.payload = {
        'pull_request' => {
          'base' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' } },
          'head' => { 'repo' => { 'full_name' => 'evilmonkey/travis-core' } }
        }
      }

      expect(request.same_repo_pull_request?).to be_falsey
    end

    it 'returns false if repo data is not available' do
      request.payload = {}

      expect(request.same_repo_pull_request?).to be_falsey
    end
  end
end
