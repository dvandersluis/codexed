# Hack to get around the fact that sanitize_sql is
# 1) a class method and 2) protected
module ActiveRecord
  class Base
    def sanitize_sql(*args)
      self.class.send(:sanitize_sql, *args)
    end
  end
end