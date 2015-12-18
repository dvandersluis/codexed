class AddSubs < ActiveRecord::Migration
  def self.up
    create_table :subs do |t|
      t.integer :journal_id, :null => false
      t.string :name, :null => false, :limit => 20
      t.string :value, :null => false, :default => ""
    end
  end
  def self.down
    drop_table :subs
  end
end
