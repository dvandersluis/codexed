class AddJournals < ActiveRecord::Migration
  def self.up
    create_table :journals, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer :user_id, :null => false
      t.string :title, :limit => 70, :null => false
      #t.string :description, :limit => 70, :null => true
      t.datetime :created_at, :null => false
      t.datetime :updated_at, :null => false
      #t.column :privacy_id, 'char(1)', :null => false, :default => 'O'
      #t.column :status_id, 'char(1)', :null => false, :default => 'A'
    end
  end
  def self.down
    drop_table :journals
  end
end
