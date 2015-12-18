class CreateFavoriteJournals < ActiveRecord::Migration
  def self.up
    create_table :favorite_journals, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer :user_id, :null => false
      t.integer :journal_id, :null => false
    end
    add_index :favorite_journals, [:user_id, :journal_id], :unique => true
  end

  def self.down
    drop_table :favorite_journals
  end
end
