class MakeCategoriesManyToMany < ActiveRecord::Migration
  def self.up
    create_table :entry_categories do |t|
      t.integer :entry_id, :null => false
      t.integer :category_id, :null => false
    end

    add_index :entry_categories, [:entry_id, :category_id], :unique => true

    remove_column :entries, :category_id

    # Change unique index on categories to include parent_id 
    remove_index :categories, :column => [:journal_id, :name]
    add_index :categories, [:journal_id, :parent_id, :name], :unique => true
  end

  def self.down
    drop_table :entry_categories

    add_column :entries, :category_id, :integer, :length => 11, :null => true

    remove_index :categories, :column => [:journal_id, :parent_id, :name]
    add_index :categories, [:journal_id, :name], :unique => true
  end
end
