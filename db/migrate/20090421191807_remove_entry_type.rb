class RemoveEntryType < ActiveRecord::Migration
  def self.up
    drop_table :entry_types
  end

  def self.down
    create_table :entry_types, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.column :key, 'char(1)', :null => false
      t.string :desc, :limit => 50, :null => false 
    end
    EntryType.create!(:key => "N", :desc => "Normal Entry")
    EntryType.create!(:key => "S", :desc => "Special Entry")
  end
end
