if Object.const_defined?(:ActionController) && ActionController.const_defined?(:Base)
  class ActionController::Base
    def action_path
      controller_path + '/' + action_name
    end
  end
end