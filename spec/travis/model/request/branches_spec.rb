require 'spec_helper'

describe Request::Branches do
  include Travis::Testing::Stubs

  let(:branches) { Request::Branches.new(request) }

  describe '#included?' do
    it 'defaults to true if no branches are included' do
      request.config['branches'] = { 'only' => nil }
      expect(branches.included?('feature')).to be_truthy
    end

    describe 'returns true if the included branches include the given branch' do
      it 'given as a string' do
        request.config['branches'] = { 'only' => 'feature' }
        expect(branches.included?('feature')).to be_truthy
      end

      it 'given as a comma separated list of branches' do
        request.config['branches'] = { 'only' => 'feature, develop' }
        expect(branches.included?('feature')).to be_truthy
      end

      it 'given as an array of branches' do
        request.config['branches'] = { 'only' => %w(feature develop) }
        expect(branches.included?('feature')).to be_truthy
      end
    end

    describe 'returns true if the given branch matches a pattern from the included branches' do
      it 'given as a string' do
        request.config['branches'] = { 'only' => '/^feature-\d+$/' }
        expect(branches.included?('feature-42')).to be_truthy
      end

      it 'given as a comma separated list of patterns' do
        request.config['branches'] = { 'only' => '/^feature-\d+$/,/^develop-\d+$/' }
        expect(branches.included?('feature-42')).to be_truthy
      end

      it 'given as an array of patterns' do
        request.config['branches'] = { 'only' => %w(/^feature-\d+$/ /^develop-\d+$/) }
        expect(branches.included?('feature-42')).to be_truthy
      end
    end

    describe 'returns false if the included branches do not include the given branch' do
      it 'given as a string' do
        request.config['branches'] = { 'only' => 'feature' }
        expect(branches.included?('master')).to be_falsey
      end

      it 'given as a comma separated list of branches' do
        request.config['branches'] = { 'only' => 'feature, develop' }
        expect(branches.included?('master')).to be_falsey
      end

      it 'given as an array of branches' do
        request.config['branches'] = { 'only' => %w(feature develop) }
        expect(branches.included?('master')).to be_falsey
      end
    end

    describe 'returns false if the given branch does not match any pattern from the included branches' do
      it 'given as a string' do
        request.config['branches'] = { 'only' => '/^feature-\d+$/' }
        expect(branches.included?('master')).to be_falsey
      end

      it 'given as a comma separated list of patterns' do
        request.config['branches'] = { 'only' => '/^feature-\d+$/,/^develop-\d+$/' }
        expect(branches.included?('master')).to be_falsey
      end

      it 'given as an array of patterns' do
        request.config['branches'] = { 'only' => %w(/^feature-\d+$/ /^develop-\d+$/) }
        expect(branches.included?('master')).to be_falsey
      end
    end
  end

  describe '#excluded?' do
    it 'defaults to false if no branches are excluded' do
      request.config['branches'] = { 'except' => nil }
      expect(branches.excluded?('feature')).to be_falsey
    end

    describe 'returns true if the excluded branches include the given branch' do
      it 'given as a string' do
        request.config['branches'] = { 'except' => 'feature' }
        expect(branches.excluded?('feature')).to be_truthy
      end

      it 'given as a comma separated list of branches' do
        request.config['branches'] = { 'except' => 'feature, develop' }
        expect(branches.excluded?('feature')).to be_truthy
      end

      it 'given as an array of branches' do
        request.config['branches'] = { 'except' => %w(feature develop) }
        expect(branches.excluded?('feature')).to be_truthy
      end
    end

    describe 'returns true if the given branch matches a pattern from the excluded branches' do
      it 'given as a string' do
        request.config['branches'] = { 'except' => '/^feature-\d+$/' }
        expect(branches.excluded?('feature-42')).to be_truthy
      end

      it 'given as a comma separated list of patterns' do
        request.config['branches'] = { 'except' => '/^feature-\d+$/,/^develop-\d+$/' }
        expect(branches.excluded?('feature-42')).to be_truthy
      end

      it 'given as an array of patterns' do
        request.config['branches'] = { 'except' => %w(/^feature-\d+$/ /^develop-\d+$/) }
        expect(branches.excluded?('feature-42')).to be_truthy
      end
    end

    describe 'returns false if the excluded branches do not include the given branch' do
      it 'given as a string' do
        request.config['branches'] = { 'except' => 'feature' }
        expect(branches.excluded?('master')).to be_falsey
      end

      it 'given as a comma separated list of branches' do
        request.config['branches'] = { 'except' => 'feature, develop' }
        expect(branches.excluded?('master')).to be_falsey
      end

      it 'given as an array of branches' do
        request.config['branches'] = { 'except' => %w(feature develop) }
        expect(branches.excluded?('master')).to be_falsey
      end
    end

    describe 'returns false if the given branch does not match any pattern from the excluded branches' do
      it 'given as a string' do
        request.config['branches'] = { 'except' => '/^feature-\d+$/' }
        expect(branches.excluded?('master')).to be_falsey
      end

      it 'given as a comma separated list of patterns' do
        request.config['branches'] = { 'except' => '/^feature-\d+$/,/^develop-\d+$/' }
        expect(branches.excluded?('master')).to be_falsey
      end

      it 'given as an array of patterns' do
        request.config['branches'] = { 'except' => %w(/^feature-\d+$/ /^develop-\d+$/) }
        expect(branches.excluded?('master')).to be_falsey
      end
    end
  end
end
