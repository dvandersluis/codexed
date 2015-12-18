# Adapted from <http://railscasts.com/episodes/62>
module ValidationDisabler
  def self.included(base)
    base.class_eval do
      extend ClassMethods
      alias_method_chain :valid_without_callbacks?, :validation_disabler
    end
  end

  def valid_without_callbacks_with_validation_disabler?
    if self.class.validation_disabled?
      true
    else
      valid_without_callbacks_without_validation_disabler?
    end
  end
  
  def disabling_validations(&block)
    self.class.disabling_validations(&block)
  end

  module ClassMethods
    def disable_validations!
      @@disable_validation = true
    end

    def enable_validations!
      @@disable_validation = false
    end

    def validation_disabled?
      @@disable_validation ||= false
    end

    def disabling_validations(&blk)
      previously_disabled = self.validation_disabled?
      self.disable_validations! unless previously_disabled
      ret = blk.call
      self.enable_validations! unless previously_disabled
      ret
    end
  end
end

class ActiveRecord::Base
  include ValidationDisabler
end
