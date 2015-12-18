class ActiveRecord::Base
  named_scope :ordered_by, lambda {|order| {:order => order} }
  named_scope :limited_to, lambda {|limit| {:limit => limit} }
  named_scope :where,      lambda {|conds| {:conditions => conds} }
  named_scope :grouped_by, lambda {|group| {:group => group} }
end