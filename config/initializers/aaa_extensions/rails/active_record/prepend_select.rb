module ActiveRecord
  class Base
    class << self
    protected
      VALID_FIND_OPTIONS << :prepend_select
      alias_method :orig_construct_finder_sql, :construct_finder_sql
      def construct_finder_sql(options)
        scope = scope(:find)
        select_options = options[:prepend_select] || (scope && scope[:prepend_select])
        sql = orig_construct_finder_sql(options)
        unless select_options.blank?
          sql.sub!(/\ASELECT /, "SELECT #{select_options}, ")
        end
        sql
      end
    end
  end
end