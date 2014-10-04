require 'spec_helper'

describe Travis::CommitCommand do
  describe 'skip' do
    it 'is not invoked by default' do
      message = "initial commit"
      expect(Travis::CommitCommand.new(message).skip?).to eq false
    end

    it 'is invoked by a commit message containing [ci skip]' do
      message = "foo [ci skip] bar"
      expect(Travis::CommitCommand.new(message).skip?).to eq true
    end

    it 'is invoked by a commit message containing [CI skip]' do
      message = "foo [CI skip] bar"
      expect(Travis::CommitCommand.new(message).skip?).to eq true
    end

    it 'is invoked by a commit message containing [ci:skip]' do
      message = "foo [ci:skip] bar"
      expect(Travis::CommitCommand.new(message).skip?).to eq true
    end

    it 'is not invoked by a commit message containing [ci unknown-command]' do
      message = "foo [ci unknown-command] bar"
      expect(Travis::CommitCommand.new(message).skip?).to eq false
    end

    it 'is invoked by the special case: [skip ci]' do
      message = "foo [skip ci] bar"
      expect(Travis::CommitCommand.new(message).skip?).to eq true
    end
  end
end
