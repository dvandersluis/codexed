class AddLanguages < ActiveRecord::Migration
  def self.up
    create_table :languages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.string :short_name, :null => false, :limit => 10
      t.string :long_name, :null => false, :limit => 30
      t.boolean :translation_exists, :default => 0
    end
    Language.create!(:short_name => 'en', :long_name  => 'English', :translation_exists => true)
  end

  def self.down
    drop_table :languages
  end
end
