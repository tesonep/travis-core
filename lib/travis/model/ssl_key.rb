require 'openssl'
class SslKey < ActiveRecord::Base
  belongs_to :repository

  validates :repository_id,
    :presence => true,
    :uniqueness => true
  validates :public_key,
    :presence => true
  validates :private_key,
    :presence => true

  before_validation :generate_keys, :on => :create

  def encrypt(string)
    build_key.public_encrypt(string)
  end

  def decrypt(string)
    build_key.private_decrypt(string)
  end

  private
  def generate_keys
    keys = OpenSSL::PKey::RSA.generate(1024)
    self.public_key = keys.public_key
    self.private_key = keys.to_pem
  end

  def build_key
    @build_key ||= OpenSSL::PKey::RSA.new(private_key)
  end
end
