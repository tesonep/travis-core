require 'spec_helper'
require 'travis/secure_config'

describe Travis::SecureConfig do
  include Support::ActiveRecord

  let(:key)     { SslKey.new.tap { |key| key.generate_keys } }
  let(:secure)  { Travis::SecureConfig.new(key)}
  let(:crypted) { key.encode('hello world') }

  it 'returns the original value if the config is not a hash' do
    expect(secure.decrypt('hello world')).to eq('hello world')
  end

  it 'returns nil if secure is nil' do
    expect(secure.decrypt(secure: nil)).to eq(nil)
  end

  it 'decrypts a string' do
    expect(secure.decrypt(secure: crypted)).to eq('hello world')
  end

  it 'decrypts with a string as a key' do
    expect(secure.decrypt('secure' => crypted)).to eq('hello world')
  end

  it 'decrypts an array with a secure entry and a string' do
    config = [{ secure: crypted }, 'hola mundo']
    expect(secure.decrypt(config)).to eq(['hello world', 'hola mundo'])
  end

  it 'decrypts a hash with a secure entry' do
    config = {
      english: { secure: crypted },
      spanish: 'hola mundo'
    }
    expect(secure.decrypt(config)).to eq({
      english: 'hello world',
      spanish: 'hola mundo'
    })
  end

  it 'decrypts a complex object of nested arrays and strings' do
    config = {
      a: [{ secure: crypted }, 'hola mundo', 42],
      b: 'hello',
      c: { z: { secure: crypted } }
    }
    expect(secure.decrypt(config)).to eq({
      a: ['hello world', 'hola mundo', 42],
      b: 'hello',
      c: { z: 'hello world' }
    })
  end

  it 'decrypts a realistic complex build config' do
    config = {
      script: "ruby -e 'p RUBY_VERSION'; true && rake test",
      rvm: ['1.8.7', '1.9.2', '1.9.3', 'rbx', 'jruby'],
      matrix: {
        exclude: [{ rvm:'rbx' }]
      },
      branches: {
        only:'master'
      },
      notifications: {
        email: false,
        campfire: {
          secure: crypted
        }
      },
      '.configured' => true
    }
    expect(secure.decrypt(config)).to eq({
      script: "ruby -e 'p RUBY_VERSION'; true && rake test",
      rvm: ['1.8.7', '1.9.2', '1.9.3', 'rbx', 'jruby'],
      matrix: {
        exclude: [{ rvm:'rbx' }]
      },
      branches: {
        only:'master'
      },
      notifications: {
        email: false,
        campfire: 'hello world'
      },
      '.configured' => true
    })
  end

  it 'keeps the string similar if it cannot be decoded' do
    config = { secure: 'hello world' }
    expect(secure.decrypt(config)).to eq('hello world')
  end
end
