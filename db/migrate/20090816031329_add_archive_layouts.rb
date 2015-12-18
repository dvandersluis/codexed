class AddArchiveLayouts < ActiveRecord::Migration
  def self.up
    create_table :archive_layouts, :force => true do |t|
      t.integer :journal_id, :null => false
      # this is the id of another archive layout, for sub-layouts
      t.integer :parent_id
      # available values for type_id:
      # * 'complete_archive'
      # * 'yearly_archive'
      # * 'monthly_archive'
      # * 'daily_archive'
      # * 'category_archive'
      # * 'specific_category_archive'
      t.string :type_id, :null => false
      t.string :title, :null => false
      t.text :content
      t.timestamps
    end
    add_index :archive_layouts, :parent_id
    add_index :archive_layouts, [:journal_id, :type_id], :unique => true

    create_table :archive_layout_types, :force => true, :id => false do |t|
      t.string :id, :null => false, :options => 'PRIMARY KEY'
      t.string :name, :null => false
    end
    add_index :archive_layout_types, :name, :unique => true
    
    [
      ['complete_archive', 'Complete archive page'],
      ['category_archive', 'Category archive page']
    ].each do |id, name|
      type = ArchiveLayoutType.new(:name => name)
      type.id = id
      type.save!
      puts "Added archive layout type '#{id}'."
    end
  end

  def self.down
    drop_table :archive_layouts
    drop_table :archive_layout_types
  end
end
