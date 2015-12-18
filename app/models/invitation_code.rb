# == Schema Information
# Schema version: 20080712010244
#
# Table name: invitation_codes
#
#  id            :integer(11)     not null, primary key
#  name          :string(32)      default(""), not null
#  user_id       :integer(11)     
#  email_address :string(50)      default(""), not null
#

class InvitationCode < ActiveRecord::Base
  belongs_to :user
end
