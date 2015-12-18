class AddContentFields < ActiveRecord::Migration
  def self.up
    add_column :templates, :raw_content, :longtext, :after => :type_id
    add_column :entries, :raw_body, :longtext, :after => :permaname
  end

  def self.down
    remove_column :templates, :raw_content
    remove_column :entries, :raw_body
  end
end
