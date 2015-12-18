module Admin::Journal::ImportHelper
  # Copied from compact_error_messages (one of our extensions)
  def assemble_error_messages(hash)
    messages = []
    hash.keys.sort.each do |attr|
      if message = hash[attr].first
        if attr == "base"
          messages << message
        else
          attr_name = ActiveRecord::Base.human_attribute_name(attr)
          messages << attr_name + I18n.t('activerecord.errors.format.separator', :default => ' ') + message
        end
      end
    end
    messages
  end
end
