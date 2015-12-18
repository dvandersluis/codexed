# Keeps track of changes you've made to the record since it was last saved
module ActiveRecord
  class Base
    def self.remembers_changes_since_last_saved
      attr_reader :before_last_saved
      after_save :store_self_when_last_saved
      class_eval do       
        def after_initialize
          @before_last_saved = new_record? ? nil : self.clone
        end
        def changes_since_last_saved
          attributes.except(self.class.primary_key) - attributes_when_last_saved.except(self.class.primary_key)
        end
        def attributes_when_last_saved
          @before_last_saved ? @before_last_saved.attributes : {}
        end
      protected
        def store_self_when_last_saved
          # This is NOT a deep clone, will this cause problems?
          @before_last_saved = self.clone
        end
      end
    end
  end
end