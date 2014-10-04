require 'spec_helper'

describe Travis::Requests::Services::Receive::Push do
  let(:payload) { Travis::Requests::Services::Receive.payload_for('push', GITHUB_PAYLOADS['gem-release']) }

  describe 'repository' do
    it 'returns all attributes required for a Repository' do
      expect(payload.repository).to eq({
        :name => 'gem-release',
        :description => 'Release your gems with ease',
        :url => 'http://github.com/svenfuchs/gem-release',
        :owner_name => 'svenfuchs',
        :owner_email => 'svenfuchs@artweb-design.de',
        :owner_type => 'User',
        :private => false,
        :github_id => 100
      })
    end
  end

  describe 'owner' do
    it 'returns all attributes required for an Owner' do
      expect(payload.owner).to eq({
        :type => 'User',
        :login => 'svenfuchs',
        :github_id => 2208
      })
    end
  end

  describe 'commit' do
    it 'returns all attributes required for a Commit' do
      expect(payload.commit).to eq({
        :commit => '46ebe012ef3c0be5542a2e2faafd48047127e4be',
        :message => 'Bump to 0.0.15',
        :branch => 'master',
        :ref => 'refs/heads/master',
        :committed_at => '2010-10-27T04:32:37Z',
        :committer_name => 'Sven Fuchs',
        :committer_email => 'svenfuchs@artweb-design.de',
        :author_name => 'Christopher Floess',
        :author_email => 'chris@flooose.de',
        :compare_url => 'https://github.com/svenfuchs/gem-release/compare/af674bd...9854592'
      })
    end

    describe 'branch processing' do
      it 'returns head_commit if commits info is not present' do
        payload.event.data['head_commit'] = payload.event.data['commits'].first
        payload.event.data['commits'] = []
        expect(payload.commit[:commit]).to eq('586374eac43853e5542a2e2faafd48047127e4be')
      end

      it 'returns master when ref is ref/heads/master' do
        expect(payload.commit[:branch]).to eq('master')
      end

      it 'returns travis when ref is ref/heads/travis' do
        payload.event.data['ref'] = "ref/heads/travis"
        expect(payload.commit[:branch]).to eq('travis')
      end

      it 'returns features/travis-ci when ref is ref/heads/features/travis-ci' do
        payload.event.data['ref'] = "ref/heads/features/travis-ci"
        expect(payload.commit[:branch]).to eq('features/travis-ci')
      end
    end

    it 'returns the last commit that isn\'t skipped' do
      payload = Travis::Requests::Services::Receive.payload_for('push', GITHUB_PAYLOADS['skip-last'])
      expect(payload.commit[:commit]).to eq('586374eac43853e5542a2e2faafd48047127e4be')
    end

    it 'returns the last skipped commit if all commits are skipped' do
      payload = Travis::Requests::Services::Receive.payload_for('push', GITHUB_PAYLOADS['skip-all'])
      expect(payload.commit[:commit]).to eq('46ebe012ef3c0be5542a2e2faafd48047127e4be')
    end
  end
end

