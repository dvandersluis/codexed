class AddJournalListed < ActiveRecord::Migration
  def self.up
    add_column :journals, :listed, :boolean, :default => 1, :after => :default_template_id
  end

  def self.down
    remove_column :journals, :listed
  end
end
