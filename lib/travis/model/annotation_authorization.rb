class AnnotationAuthorization < ActiveRecord::Base
  attr_accessible :active

  belongs_to :repository
  belongs_to :annotation_provider
end
