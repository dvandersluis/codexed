class ActiveRecord::Base
  class << self
    def add_group!(sql, group, having, scope = :auto)
      if group or having
        sql << " GROUP BY #{group}" if group
        sql << " HAVING #{sanitize_sql_for_conditions(having)}" if having
      else
        scope = scope(:find) if :auto == scope
        if scope && (scoped_group = scope[:group] or scoped_having = scope[:having])
          sql << " GROUP BY #{scoped_group}" if scoped_group
          sql << " HAVING #{sanitize_sql_for_conditions(scoped_having)}" if scoped_having
        end
      end
    end
  end
end