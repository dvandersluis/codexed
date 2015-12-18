class ExtendSubsValue < ActiveRecord::Migration
  def self.up
    change_column :subs, :value, :text
  end

  def self.down
    change_column :subs, :value, :string, :limit => 255, :default => "", :null => false
  end
end
