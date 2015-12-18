# OO-ified connection.select_all
require 'openhash'
module ActiveRecord
  class Base
    class << self
      def select_all(query)
        rows = connection.select_all( sanitize_sql(query) )
        rows.map! do |row|
          oh = OpenHash.new(row)
          oh.each {|k, v| oh[k] = select_type_cast(v) }
          oh
        end
        rows
      end
      def select_one(query)
        select_all(query).first
      end
      def select_value(query)
        select_type_cast(
          connection.select_value( sanitize_sql(query) )
        )
      end
      def select_type_cast(v)
        return unless v
        if md = v.match(/^(\d{4})-(\d{2})-(\d{2})$/)
          Date.new(*md.captures.map(&:to_i)) rescue v
        elsif md = v.match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/)
          Time.local(*md.captures.map(&:to_i)) rescue v
        elsif v =~ /^\d+$/
          v.to_i
        elsif v =~ /^\d+(?:\.\d+)+$/
          v.to_f
        elsif v == "true"
          true
        elsif v == "false"
          false
        else
          v
        end
      end
    end
  end
end