class ExpandSessionDataColumn < ActiveRecord::Migration
  def self.up
    change_column :sessions, :data, :longtext
  end

  def self.down
    change_column :sessions, :data, :text
  end
end
