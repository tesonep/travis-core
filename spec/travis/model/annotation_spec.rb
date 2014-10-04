require 'spec_helper'

describe Annotation do
  include Support::ActiveRecord

  let(:annotation) { Factory.build(:annotation) }

  describe 'validations' do
    it 'only allows http or https URLs' do
      annotation.url = 'ftp://travis-ci.org'
      expect(annotation.save).to be_falsey
      expect(annotation.errors[:url].first).to match(/scheme/)
    end

    it 'only allows valid URLs' do
      annotation.url = 'http://travis-ci.org:80b/'
      expect(annotation.save).to be_falsey
      expect(annotation.errors[:url].first).to match(/invalid/)
    end
  end
end
