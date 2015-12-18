class AddPrefabsPart2 < ActiveRecord::Migration
  def self.up
    add_column :templates, :prefab_name, :string, :after => :type_id, :null => true
  end

  def self.down
    remove_column :templates, :prefab_name
  end
end
