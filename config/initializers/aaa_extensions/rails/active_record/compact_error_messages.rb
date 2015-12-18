module ActiveRecord
  class Errors
    # Limit messages per object to one, and sort objects as they come out
    def compact_messages
      messages = []
      @errors.keys.sort.each do |attr|
        if msg = @errors[attr].first
          if attr == "base"
            messages << message
          else
            attr_name = @base.class.human_attribute_name(attr)
            messages << attr_name + I18n.t('activerecord.errors.format.separator', :default => ' ') + message
          end
        end
      end
      messages
    end
  end
end