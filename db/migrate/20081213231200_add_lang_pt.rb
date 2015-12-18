class AddLangPt < ActiveRecord::Migration
  def self.up
    Language.find_by_short_name('pt').update_attributes({:translation_exists => true})
  end

  def self.down
    Language.find_by_short_name('pt').update_attributes({:translation_exists => false})
  end
end
