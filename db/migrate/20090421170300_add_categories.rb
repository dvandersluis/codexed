class AddCategories < ActiveRecord::Migration
  def self.up
    create_table :categories do |t|
      t.integer :journal_id, :null => false
      t.string :name, :limit => 50, :null => false
      t.integer :parent_id, :null => true
    end

    add_index :categories, [:journal_id, :name], :unique => true

    create_table :tags do |t|
      t.string :name, :limit => 200, :null => false
    end

    add_index :tags, :name, :unique => true

    create_table :entry_tags do |t|
      t.integer :entry_id, :null => false
      t.integer :tag_id, :null => false
    end

    add_index :entry_tags, [:entry_id, :tag_id], :unique => true

    # Add category_id to entries
    add_column :entries, :category_id, :integer, :length => 11, :null => true
  end

  def self.down
    drop_table :categories
    drop_table :tags
    drop_table :entry_tags

    remove_column :entries, :category_id
  end
end
