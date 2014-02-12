require 'active_record'
require 'travis/model/encrypted_column'

class AnnotationProvider < ActiveRecord::Base
  has_many :annotations
  has_many :annotation_authorizations
  has_many :repositories, through: :annotation_authorizations

  serialize :api_key, Travis::Model::EncryptedColumn.new

  def self.authenticate_provider(username, key)
    provider = where(api_username: username).first

    return unless provider && provider.api_key == key

    provider
  end

  def annotation_for_job(job_id)
    annotations.where(job_id: job_id).first || annotations.build(job_id: job_id)
  end

  def active_for_job?(job_id)
    job = Job.find(job_id)
    repo = job.repository

    puts "repositories: #{repositories}, repo: #{repo}"
    unless repositories.include?(repo)
      return false
    end

    annotation_authorizations.where(repository_id: repo.id).first.tap {|x| puts "foo: #{x}"}.active
  end
end
