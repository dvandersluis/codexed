class RemoveJournalDefaultTemplateId < ActiveRecord::Migration
  def self.up
    remove_column :journals, :default_template_id
  end

  def self.down
    add_column :journals, :default_template_id, :integer, :after => :title
  end
end
