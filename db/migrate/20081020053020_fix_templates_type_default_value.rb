class FixTemplatesTypeDefaultValue < ActiveRecord::Migration
  def self.up
    change_column :templates, :type, 'varchar(10)', :null => false, :default => 'Template' 
  end

  def self.down
    change_column :templates, :type, 'varchar(10)', :null => true, :default => nil
  end
end
