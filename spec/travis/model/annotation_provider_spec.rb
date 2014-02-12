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
    let(:repository) { stub_repository }

    let(:job) { Factory(:test, repository: repository) }

    before :each do
      Job.stubs(:find).with(job.id).returns job
    end

    context 'when authorization for job\'s repo does not exist' do
      it 'returns false' do
        provider.active_for_job?(job.id).should be_false
      end
    end

    context 'when authorization for job\'s repo exists but inactive' do
      let(:auth) { stub_annotation_authorization(active: false, repositories: [job.repository]) }

      it 'returns false' do
        provider.active_for_job?(job.id).should be_false
      end
    end

    context 'when authorization for job\'s repo exists and active' do
      before :each do
        provider.stubs(:repositories).returns( [repository] )
      end

      it 'returns true' do
        provider.active_for_job?(job.id).should be_true
      end
    end

  end
end
