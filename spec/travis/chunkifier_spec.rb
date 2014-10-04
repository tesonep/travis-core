# encoding: utf-8
require 'spec_helper'

module Travis
  describe Chunkifier do
    let(:chunk_size) { 15 }
    let(:chunk_split_size) { 5 }
    let(:subject) { Chunkifier.new(content, chunk_size, :json => true) }

    context 'with newlines' do
      let(:content) { "01\n234501\n234501\n2345" }

      describe '#parts' do
        subject { super().parts }
        it { is_expected.to eq(["01\n234501\n2", "34501\n2345"]) }
      end
    end

    context 'with UTF-8 chars' do
      let(:chunk_split_size) { 1 }
      let(:content) { "𤭢abcą" }

      describe '#parts' do
        subject { super().parts }
        it { is_expected.to eq(["𤭢abc", "ą"]) }
      end

      it 'should keep parts under chunk_size taking into account conversion to json and bytes' do
        expect(subject.parts.map { |p| p.to_json.bytesize }).to eq([11, 8])
      end
    end

    context 'with bigger chunk_size' do
      let(:chunk_size) { 100 }
      let(:content) { "01\nąąąą" * 1000 }

      it 'should keep parts under chunk_size taking into account conversion to json and bytes' do
        expect(subject.parts.all? { |p| p.to_json.bytesize <= 100 }).to be_truthy
      end
    end
  end
end
