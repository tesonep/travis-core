class CreateAnnotationAuthorizations < ActiveRecord::Migration
  def change
    create_table :annotation_authorizations do |t|
      t.belongs_to :repository
      t.belongs_to :annotation_provider
      t.boolean :active

      t.timestamps
    end
  end
end
