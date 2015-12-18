class AddUserProfileInfo < ActiveRecord::Migration
  def self.up
    # ancient?
    add_column :users, :ancient, :boolean, :after => :activation_key, :null => false, :default => 0
    
    # gender
    add_column :users, :gender, 'char(1)', :after => :email, :null => true
    
    # country stuff
    create_table :countries do |t|
      t.string :name, :limit => 255, :null => false
    end

    # The country model was deleted after this migration was created; if migrating
    # and Country doesn't exist, don't create countries in the database
    if defined? Country
      ActionView::Helpers::FormOptionsHelper::COUNTRIES.each_with_index do |name, id|
        Country.create!(:id => id, :name => name)
      end
    end

    add_column :users, :country_id, :integer, :after => :gender, :null => true
  end
  def self.down
    remove_column :users, :ancient
    remove_column :users, :gender
    remove_column :users, :country_id
    drop_table :countries
    drop_table :languages
  end
end
