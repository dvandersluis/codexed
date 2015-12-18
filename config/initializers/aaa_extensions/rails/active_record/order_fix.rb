# This fixes AR::Base.find so that :order options in scopes
# are overwritten instead of being merged, which is completely unintuitive
class << ActiveRecord::Base
private
  def add_order!(sql, order, scope = :auto)
    sql << " ORDER BY #{order}" if order
  end
end