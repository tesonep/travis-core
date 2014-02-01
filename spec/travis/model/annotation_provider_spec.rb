require 'spec_helper'

describe AnnotationProvider do
  include Travis::Testing::Stubs, Support::ActiveRecord

  let(:provider) { Factory(:annotation_provider) }

  describe '.authenticate_provider' do
    context 'given a valid username and key' do
      it 'authenticates the provider' do
        described_class.authenticate_provider(provider.api_username, provider.api_key).should eq(provider)
      end
    end

    context 'given an invalid username' do
      it 'does not authenticate the provider' do
        described_class.authenticate_provider('someone-else', provider.api_key).should be_nil
      end
    end

    context 'given an invalid key' do
      it 'does not authenticate the provider' do
        described_class.authenticate_provider(provider.api_username, 'some-other-key').should be_nil
      end
    end

    context 'with an encrypted key' do
      it 'authenticates the provider' do
        provider.update_column(:api_key, 'encrypted-key')

        Travis::Model::EncryptedColumn.any_instance.stubs(encrypt?: true, key: 'abcd', load: '...')
        Travis::Model::EncryptedColumn.any_instance.expects(:load).with('encrypted-key').returns('a-key')

        described_class.authenticate_provider(provider.api_username, 'a-key').should eq(provider)
      end
    end
  end

  describe '#annotation_for_job' do
    let(:job) { Factory(:test) }

    context 'given an annotation already exists for the job' do
      it 'returns the annotation' do
        annotation = Factory(:annotation, annotation_provider: provider, job: job)
        provider.annotation_for_job(job.id).should eq(annotation)
      end
    end

    context 'given no annotation exists yet for the job' do
      it 'returns a new annotation object' do
        provider.annotation_for_job(job.id).new_record?.should be_true
      end
    end
  end

  describe '#active_for_job?' do
    let(:build)   { stub_build(state: :failed, repository: repository) }
    let(:subject) { Travis::Addons::Email::EventHandler }
    let(:payload) { Travis::Api.data(build, for: 'event', version: 'v0') }
    let(:repository) {
      stub_repo(users: [
        stub_user(emails: [stub_email(email: 'author-1@email.com'   )]),
        stub_user(emails: [stub_email(email: 'committer-1@email.com')])
      ])
    }
    let(:job) { Job::Test.create!(owner: Factory(:user), repository: repository,
      commit: Factory(:commit), source: Factory(:build)) }

    context 'when authorization for job\'s repo does not exist' do
      it 'returns false' do
        provider.active_for_job?(job.id).should be_false
      end
    end

    context 'when authorization for job\'s repo exists but inactive' do
      before :each do
        auth = provider.annotation_authorizations.create!(active: false, repository: job.repository)
        auth.active = false
      end

      it 'returns false' do
        provider.active_for_job?(job.id).should be_false
      end
    end

    context 'when authorization for job\'s repo exists and active' do
      before :each do
        auth = provider.annotation_authorizations.create!(active: true, repository: repository, annotation_provider: provider)

      end

      it 'returns false' do
        puts "provider.annotation_authorizations: #{provider.annotation_authorizations}"
        puts "provider.repositories: #{provider.repositories}"
        provider.active_for_job?(job.id).should be_true
      end
    end

  end
end
