require 'spec_helper'

describe Log do
  include Support::ActiveRecord

  let!(:log)  { job.log }
  let(:job)   { Factory.create(:test, log: Factory.create(:log, content: '')) }
  let(:lines) { ["line 1\n", "line 2\n", 'line 3'] }

  describe 'class methods' do
    it 'is archived only when archive is verified' do
      log.archived_at = Time.now
      expect(log).not_to be_archived
      log.archive_verified = true
      expect(log).to be_archived
    end

    describe '#to_json' do
      it 'returns JSON representation of the record' do
        json = JSON.parse(job.log.to_json)
        expect(json['log']['id']).to eq(job.log.id)
      end
    end
  end

  describe 'content' do
    it 'while not aggregated it returns the aggregated parts' do
      lines.each_with_index { |line, ix| Log::Part.create!(log_id: log.id, content: line, number: ix) }
      expect(log.content).to eq(lines.join)
    end

    it 'while not aggregated it appends to an existing log' do
      job.log.update_attributes(content: 'foo')
      Log::Part.create!(log_id: log.id, content: 'bar')
      expect(log.content).to eq('foobar')
    end

    it 'if aggregated returns the aggregated parts' do
      log.update_attributes!(content: 'content', aggregated_at: Time.now)
      expect(log.content).to eq('content')
    end
  end

  describe '#clear!' do
    it 'clears log parts' do
      Log::Part.create!(log_id: log.id, content: 'bar')
      expect {
        expect {
          log.clear!
        }.to change { log.parts.length }.by(-1)
      }.to_not change { Log.count }
    end

    it 'resets content' do
      log.update_attributes!(content: 'foo')
      log.clear!
      expect(log.reload.content).to eq('')
    end

    it 'resets aggregated_at' do
      log.update_attributes!(aggregated_at: Time.now)
      log.clear!
      expect(log.reload.aggregated_at).to be_nil
    end

    it 'resets archived_at' do
      log.update_attributes!(archived_at: Time.now)
      log.clear!
      expect(log.reload.archived_at).to be_nil
    end

    it 'resets archive_verified' do
      log.update_attributes!(archive_verified: true)
      log.clear!
      expect(log.reload.archive_verified).to be_nil
    end
  end
end

