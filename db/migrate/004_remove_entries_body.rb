class RemoveEntriesBody < ActiveRecord::Migration
  def self.up
    remove_column :entries, :body
  end
  def self.down
    add_column :entries, :body, :text, :after => :permalink, :null => true
  end
end
