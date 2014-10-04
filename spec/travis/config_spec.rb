require 'spec_helper'
require 'active_support/core_ext/hash/slice'

describe Travis::Config do
  let(:config) { Travis::Config.new }

  after :each do
    ENV.delete('DATABASE_URL')
    ENV.delete('travis_config')
    Travis.instance_variable_set(:@config, nil)
  end

  describe 'endpoints' do
    it 'returns an object even without endpoints entry' do
      expect(config.endpoints.foo).to be_nil
    end

    it 'returns endpoints if it is set' do
      ENV['travis_config'] = YAML.dump('endpoints' => { 'ssh_key' => true })
      expect(config.endpoints.ssh_key).to be_truthy
    end

    it 'allows to set keys on enpoints when it is nil' do
      expect(config.endpoints.foo).to be_nil

      config.endpoints.foo = true

      expect(config.endpoints.foo).to be_truthy
    end
  end

  describe 'Hashr behaviour' do
    it 'is a Hashr instance' do
      expect(config).to be_kind_of(Hashr)
    end

    it 'returns Hashr instances on subkeys' do
      ENV['travis_config'] = YAML.dump('redis' => { 'url' => 'redis://localhost:6379' })
      expect(config.redis).to be_kind_of(Hashr)
    end

    it 'returns Hashr instances on subkeys that were set to Ruby Hashes' do
      config.foo = { :bar => { :baz => 'baz' } }
      expect(config.foo.bar).to be_kind_of(Hashr)
    end
  end

  describe 'defaults' do
    it 'notifications defaults to []' do
      expect(config.notifications).to eq([])
    end

    it 'notifications.email defaults to {}' do
      expect(config.email).to eq({})
    end

    it 'queues defaults to []' do
      expect(config.queues).to eq([])
    end

    it 'ampq.host defaults to "localhost"' do
      expect(config.amqp.host).to eq('localhost')
    end

    it 'ampq.prefetch defaults to 1' do
      expect(config.amqp.prefetch).to eq(1)
    end

    it 'queue.limit.by_owner defaults to {}' do
      expect(config.queue.limit.by_owner).to eq({})
    end

    it 'queue.limit.default defaults to 5' do
      expect(config.queue.limit.default).to eq(5)
    end

    it 'queue.interval defaults to 3' do
      expect(config.queue.interval).to eq(3)
    end

    it 'queue.interval defaults to 3' do
      expect(config.queue.interval).to eq(3)
    end

    it 'logs.shards defaults to 1' do
      expect(config.logs.shards).to eq(1)
    end

    it 'database' do
      expect(config.database).to eq({
        :adapter => 'postgresql',
        :database => 'travis_test',
        :encoding => 'unicode',
        :min_messages => 'warning'
      })
    end
  end

  describe 'using DATABASE_URL for database configuration if present' do
    it 'works when given a url with a port' do
      ENV['DATABASE_URL'] = 'postgres://username:password@hostname:port/database'

      expect(config.database.to_hash.slice(:adapter, :host, :port, :database, :username, :password)).to eq({
        :adapter => 'postgresql',
        :host => 'hostname',
        :port => 'port',
        :database => 'database',
        :username => 'username',
        :password => 'password'
      })
    end

    it 'works when given a url without a port' do
      ENV['DATABASE_URL'] = 'postgres://username:password@hostname/database'

      expect(config.database.to_hash.slice(:adapter, :host, :port, :database, :username, :password)).to eq({
        :adapter => 'postgresql',
        :host => 'hostname',
        :database => 'database',
        :username => 'username',
        :password => 'password'
      })
    end
  end

  describe 'the example config file' do
    let(:data)    { {} }
    before(:each) { Travis::Config.stubs(:load_file).returns(data) }

    it 'can access pusher' do
      expect { config.pusher.key }.not_to raise_error
    end

    it 'can access all keys recursively' do
      nested_access = lambda do |config, data|
        data.keys.each do |key|
          expect { config.send(key) }.not_to raise_error
          nested_access.call(config.send(key), data[key]) if data[key].is_a?(Hash)
        end
      end
      nested_access.call(config, data)
    end
  end

  it 'deep symbolizes arrays, too' do
    config = Travis::Config.new('queues' => [{ 'slug' => 'rails/rails', 'queue' => 'rails' }])
    expect(config.queues.first.values_at(:slug, :queue)).to eq(['rails/rails', 'rails'])
  end
end

