class User < ActiveRecord::Base
  extend LostInCode::LoginSystem::ClassMethods
  include LostInCode::LoginSystem::InstanceMethods
end