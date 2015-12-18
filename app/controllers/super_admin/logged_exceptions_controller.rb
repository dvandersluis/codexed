class SuperAdmin::LoggedExceptionsController < SuperAdmin::BaseController
  include ExceptionLoggableControllerMixin
  self.application_name = "Codexed"
end