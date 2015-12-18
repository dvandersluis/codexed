# == Schema Information
# Schema version: 20080712010244
#
# Table name: languages
#
#  id                 :integer(11)     not null, primary key
#  short_name         :string(10)      default(""), not null
#  long_name          :string(30)      default(""), not null
#  translation_exists :boolean(1)      
#

require 'has_strings'

class Language < ActiveRecord::Base

  include HasStrings

  COMMON_LANGUAGES = %w(en es fr de it ja zh pt ru ko)

  named_scope :allowed_in_profile, :conditions => { :allowed_in_profile => true }
  named_scope :translations, :conditions => { :translation_exists => true }
  named_scope :common, :conditions => [ "short_name IN (?)", COMMON_LANGUAGES ]
  named_scope :uncommon, :conditions => [ "short_name NOT IN (?)", COMMON_LANGUAGES ]

  class << self
    def ordered
      if self.count > COMMON_LANGUAGES.size
        common.sort_by(&:ascii_name) + uncommon.sort_by(&:ascii_name)
      else
        all.sort_by(&:ascii_name)
      end
    end

    # Get the most popular languages. These are the language options that will appear on the members page
    def popular(count = nil)
      count = 8 unless count.is_a? Integer

      find_by_sql("SELECT l.*
        FROM `journals` AS j
        LEFT JOIN languages AS l
        ON l.id = j.language_id 
        WHERE language_id IS NOT NULL
          AND j.privacy != 'C'
          AND j.listed = true
        GROUP BY language_id
        LIMIT #{count}"
      ).sort_by! { |lang| Language.strings[lang.id].uninternationalize }
    end
  end
end
