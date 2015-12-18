class AddPrivacy < ActiveRecord::Migration
  def self.up
    add_column :journals, :privacy, 'char(1)', :after => :listed, :null => false, :default => 'O'
    add_column :journals, :crypted_journal_password, :text, :after => :privacy, :null => true
    add_column :journals, :crypted_entries_password, :text, :after => :crypted_journal_password, :null => true
    add_column :entries, :privacy, 'char(1)', :after => :type_id, :null => false, :default => 'O'
  end

  def self.down
    remove_column :journals, :privacy
    remove_column :journals, :crypted_journal_password
    remove_column :journals, :crypted_entries_password
    remove_column :entries, :privacy
  end
end
