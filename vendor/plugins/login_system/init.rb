require 'login_system'
if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend(LostInCode::LoginSystem::MacroMethods)
end

require 'login_system_controller'
if defined?(ActionController::Base)
  ActionController::Base.extend(LostInCode::LoginSystemController::MacroMethods)
end

