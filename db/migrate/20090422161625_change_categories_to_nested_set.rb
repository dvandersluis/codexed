class ChangeCategoriesToNestedSet < ActiveRecord::Migration
  def self.up
    add_column :categories, :lft, :integer, :length => 11
    add_column :categories, :rgt, :integer, :length => 11
  end

  def self.down
    remove_column :categories, :lft
    remove_column :categories, :rgt
  end
end
