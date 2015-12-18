require File.dirname(__FILE__) + '/install'
require 'ajax_error_handlers_controller'

ActionController::Base.send(:include, LostInCode::AjaxErrorHandlersController)
