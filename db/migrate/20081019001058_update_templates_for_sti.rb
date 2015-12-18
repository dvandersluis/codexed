class UpdateTemplatesForSti < ActiveRecord::Migration
  def self.up
    change_column :templates, :type_id, 'varchar(10)', :default => 'Template'

    Template.all.each do |t|
      new_type = (t.type_id == "C") ? 'Template' : (t.type_id == "P") ? 'Prefab' : t.type_id
      t.update_attributes!(:type_id => new_type)
    end
    
    rename_column :templates, :type_id, :type
  end

  def self.down
    rename_column :templates, :type, :type_id

    Template.all.each do |t|
      new_type = (t.type_id == "Template") ? 'C' : (t.type_id == "Prefab") ? 'P' : t.type
      t.update_attributes!(:type_id => new_type)
    end
  
    change_column :templates, :type_id, 'char(1)', :default => 'C'
  end
end
