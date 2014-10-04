require 'spec_helper'

describe Travis::Notification::Publisher::Log do
  include Support::Notifications

  let(:io) { StringIO.new }
  let(:log) { io.string }

  before do
    Travis.logger = Logger.new(io)
    Travis.logger.level = Logger::INFO
  end

  it 'writes to Travis.logger' do
    expect(log).to be_empty
    publish
    expect(log).not_to be_empty
  end

  it 'prints out the :msg value' do
    publish msg: 'FOO BAR'
    expect(log).to include('Object#instrumented:completed FOO BAR')
  end

  it 'defaults to INFO' do
    publish(msg: 'foo bar')
    expect(log).to match(/I TID=.*? Object#instrumented:completed foo bar/)
  end

  it 'uses ERROR if an exception occured' do
    instrument(exception: true).publish(msg: 'foo bar')
    expect(log).to match(/E TID=.*? Object#instrumented:completed foo bar/)
  end

  it 'does not include extra information if no exception occured' do
    publish(foo: 'bar')
    expect(log).not_to include("foo: 'bar'")
  end

  # it 'does include extra information if no exception occured but log level is DEBUG' do
  #   Travis.logger.level = Logger::DEBUG
  #   log.should include("foo: \"bar\"")
  # end

  it 'does include extra information if an exception occured' do
    instrument(exception: true).publish(foo: 'bar')
    expect(log).to include("\"bar\"")
  end
end
