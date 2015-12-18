class AddSpecialEntries < ActiveRecord::Migration
  def self.up
    create_table :entry_types, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.column :key, 'char(1)', :null => false
      t.string :desc, :limit => 50, :null => false 
    end
    if defined?(EntryType)
      EntryType.create!(:key => "N", :desc => "Normal Entry")
      EntryType.create!(:key => "S", :desc => "Special Entry")
    end
    add_column :entries, :type_id, 'char(1)', :after => :summary, :null => false, :default => 'N'
  end
  def self.down
    drop_table :entry_types
    remove_column :entries, :type_id
  end
end
