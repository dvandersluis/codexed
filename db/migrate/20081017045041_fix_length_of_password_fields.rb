class FixLengthOfPasswordFields < ActiveRecord::Migration
  def self.up
    change_column :journals, :crypted_journal_password, :string, :limit => 40
    change_column :journals, :crypted_entries_password, :string, :limit => 40
  end

  def self.down
    change_column :journals, :crypted_journal_password, :text
    change_column :journals, :crypted_entries_password, :text
  end
end
