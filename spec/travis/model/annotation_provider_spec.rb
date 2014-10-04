require 'spec_helper'

describe AnnotationProvider do
  include Support::ActiveRecord

  let(:provider) { Factory(:annotation_provider) }

  describe '.authenticate_provider' do
    context 'given a valid username and key' do
      it 'authenticates the provider' do
        expect(described_class.authenticate_provider(provider.api_username, provider.api_key)).to eq(provider)
      end
    end

    context 'given an invalid username' do
      it 'does not authenticate the provider' do
        expect(described_class.authenticate_provider('someone-else', provider.api_key)).to be_nil
      end
    end

    context 'given an invalid key' do
      it 'does not authenticate the provider' do
        expect(described_class.authenticate_provider(provider.api_username, 'some-other-key')).to be_nil
      end
    end

    context 'with an encrypted key' do
      it 'authenticates the provider' do
        provider.update_column(:api_key, 'encrypted-key')

        Travis::Model::EncryptedColumn.any_instance.stubs(encrypt?: true, key: 'abcd', load: '...')
        Travis::Model::EncryptedColumn.any_instance.expects(:load).with('encrypted-key').returns('a-key')

        expect(described_class.authenticate_provider(provider.api_username, 'a-key')).to eq(provider)
      end
    end
  end

  describe '#annotation_for_job' do
    let(:job) { Factory(:test) }

    context 'given an annotation already exists for the job' do
      it 'returns the annotation' do
        annotation = Factory(:annotation, annotation_provider: provider, job: job)
        expect(provider.annotation_for_job(job.id)).to eq(annotation)
      end
    end

    context 'given no annotation exists yet for the job' do
      it 'returns a new annotation object' do
        expect(provider.annotation_for_job(job.id).new_record?).to be_truthy
      end
    end
  end
end
