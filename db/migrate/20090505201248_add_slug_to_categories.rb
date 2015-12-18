class AddSlugToCategories < ActiveRecord::Migration
  def self.up
    add_column :categories, :slug, :string, :limit => 200, :after => :name
    change_column :categories, :name, :string, :limit => 200
  end

  def self.down
    remove_column :categories, :slug
    change_column :categories, :name, :string, :limit => 50
  end
end
