class AddEntries < ActiveRecord::Migration
  def self.up
    create_table :entries, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      #t.integer :user_id, :null => false
      t.integer :journal_id, :null => false
      t.string :title, :null => false
      t.string :permaname, :limit => 60, :null => false
      t.text :body, :null => true
      t.text :summary, :null => true
      t.datetime :created_at, :null => false
      t.datetime :custom_created_at, :null => false
      t.datetime :updated_at, :null => false
      #t.column :published_status_id, 'char(1)', :null => false, :default => 'P'
      #t.column :comment_status_id, 'char(1)', :null => false, :default => 'O'
      #t.column :privacy_id, 'char(1)', :null => false, :default => 'O'
      #t.column :status_id, 'char(1)', :null => false, :default => 'A'
    end
  end
  def self.down
    drop_table :entries
  end
end
