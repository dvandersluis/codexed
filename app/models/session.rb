# == Schema Information
# Schema version: 20080712010244
#
# Table name: sessions
#
#  id         :integer(11)     not null, primary key
#  session_id :string(255)     default(""), not null
#  data       :text            
#  created_at :datetime        
#  updated_at :datetime        
#

class Session < ActiveRecord::Base
end
