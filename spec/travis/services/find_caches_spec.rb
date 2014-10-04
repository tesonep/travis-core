require 'spec_helper'

describe Travis::Services::FindCaches do
  include Support::ActiveRecord, Support::S3

  let(:user) { User.first || Factory(:user) }
  let(:service) { described_class.new(user, params) }
  let(:repo) { Factory(:repository, :owner_name => 'travis-ci', :name => 'travis-core') }
  let(:cache_options) {{ s3: { bucket_name: '' } }}
  let(:result) { service.run }
  let(:has_access) { true }
  subject { result }

  before :each do
    Travis.config.roles = {}
    Travis.config.cache_options = cache_options
    user.stubs(:permission?).returns(has_access)
  end

  describe 'given a repository_id' do
    let(:params) {{ repository_id: repo.id }}

    describe 'without any caches' do
      it { is_expected.to eq([]) }
    end

    describe 'with caches' do
      before do
        s3_bucket << "#{repo.github_id}/master/cache--example1.tbz"
        s3_bucket << "#{repo.github_id}/other/cache--example2.tbz"
        s3_bucket << "#{repo.github_id.succ}/master/cache--example3.tbz"
      end

      describe '#size' do
        subject { super().size }
        it { is_expected.to eq(2) }
      end

      describe 'the cache instances' do
        subject { result.first }

        describe '#slug' do
          subject { super().slug }
          it { is_expected.to eq('cache--example1') }
        end

        describe '#branch' do
          subject { super().branch }
          it { is_expected.to eq('master') }
        end

        describe '#repository' do
          subject { super().repository }
          it { is_expected.to eq(repo) }
        end

        describe '#size' do
          subject { super().size }
          it { is_expected.to eq(0) }
        end
      end

      describe 'with branch' do
        let(:params) {{ repository_id: repo.id, branch: 'other' }}

        describe '#size' do
          subject { super().size }
          it { is_expected.to eq(1) }
        end
      end

      describe 'with match' do
        let(:params) {{ repository_id: repo.id, match: 'example1' }}

        describe '#size' do
          subject { super().size }
          it { is_expected.to eq(1) }
        end
      end

      describe 'without access' do
        let(:has_access) { false }

        describe '#size' do
          subject { super().size }
          it { is_expected.to eq(0) }
        end
      end

      describe 'without s3 credentials' do
        let(:cache_options) {{ }}
        before { service.logger.expects(:warn).with("[services:find-caches] S3 credentials missing") }
        it { is_expected.to eq([]) }
      end
    end
  end
end