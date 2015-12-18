class AddGenericChineseForProfile < ActiveRecord::Migration
  def self.up
    Language.find_by_short_name('zh-hans').update_attributes({:allowed_in_profile => false})
    Language.find_by_short_name('zh-hant').update_attributes({:allowed_in_profile => false})
    Language.create!(:short_name => 'zh', :long_name => 'Chinese', :localized_name => '中文', :allowed_in_profile => true, :translation_exists => false)
  end

  def self.down
    Language.find_by_short_name('zh-hans').update_attributes({:allowed_in_profile => true})
    Language.find_by_short_name('zh-hant').update_attributes({:allowed_in_profile => true})
    Language.find_by_short_name('zh').delete
  end
end
