class ChangeEntriesToPosts < ActiveRecord::Migration
  def self.up
    rename_table :entries, :posts
    
    rename_table :entry_categories, :post_categories
    rename_column :post_categories, :entry_id, :post_id
    
    rename_table :entry_tags, :post_tags
    rename_column :post_tags, :entry_id, :post_id
  end

  def self.down
    rename_table :posts, :entries
    
    rename_table :post_categories, :entry_categories
    rename_column :entry_categories, :post_id, :entry_id

    rename_table :post_tags, :entry_tags
    rename_column :entry_tags, :post_id, :entry_id
  end
end
