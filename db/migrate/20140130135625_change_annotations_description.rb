class ChangeAnnotationsDescription < ActiveRecord::Migration
  def up
    change_table :annotations do |t|
      t.change :description, :string
    end
  end

  def down
    change_table :annotations do |t|
      t.change :description, :text
    end
  end
end
