if defined? ActiveRecord::ConnectionAdapters::AbstractAdapter
  # Extend MysqlAdapter to support ordering of columns, and custom MySQL options.
  # Note that this requires MySQL 5.0
  module ActiveRecord
    module ConnectionAdapters
      class MysqlAdapter < AbstractAdapter
        def add_column_options!(sql, options) #:nodoc:
          sql << " DEFAULT #{quote(options[:default], options[:column])}" if options_include_default?(options)
          sql << " NOT NULL" if options[:null] == false
          sql << " AFTER #{options[:after]}" if options[:after]
          sql << " "+options[:options] if options[:options]
        end
      end
    end # ConnectionAdapters
  end # ActiveRecord
end