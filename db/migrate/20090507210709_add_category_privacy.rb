class AddCategoryPrivacy < ActiveRecord::Migration
  def self.up
    add_column :categories, :privacy, 'char(1)', :after => :slug, :null => false, :default => 'O'
  end

  def self.down
    remove_column :categories, :privacy
  end
end
