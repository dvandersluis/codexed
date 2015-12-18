class AddPrefabs < ActiveRecord::Migration
  def self.up
    create_table :template_types, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.column :key, 'char(1)', :null => false
      t.string :desc, :limit => 50, :null => false
    end
    add_column :templates, :type_id, 'char(1)', :after => :name, :null => false, :default => 'C'
  end

  def self.down
    drop_table :template_types
    remove_column :templates, :type_id
  end
end
