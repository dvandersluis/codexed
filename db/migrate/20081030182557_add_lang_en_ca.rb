class AddLangEnCa < ActiveRecord::Migration
  def self.up
    Language.new(:short_name => 'en-ca', :long_name => 'English (Canada)', :translation_exists => true).save
  end

  def self.down
    Language.find_by_short_name('en-ca').destroy
  end
end
