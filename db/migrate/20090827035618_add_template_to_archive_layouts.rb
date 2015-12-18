class AddTemplateToArchiveLayouts < ActiveRecord::Migration
  def self.up
    add_column :archive_layouts, :template_id, :integer, :after => :content
  end

  def self.down
    remove_column :archive_layouts, :template_id
  end
end
