module MeasureArInstantiation
  def measure_ar_instantiation!
    (class << self; self; end).class_eval do
      def find_by_sql(sql)
        records = connection.select_all(sanitize_sql(sql), "#{name} Load")
        puts_time("Active Record Instantiation") do
          records.collect! { |record| instantiate(record) }
        end
      end
  
      def find_with_associations(options = {})
        catch :invalid_query do
          join_dependency = JoinDependency.new(self, merge_includes(scope(:find, :include), options[:include]), options[:joins])
          rows = select_all_rows(options, join_dependency)
          return puts_time("Active Record Instantiation (Association)") do
            join_dependency.instantiate(rows)
          end
        end
        []
      end
    end
  end
end

ActiveRecord::Base.extend(MeasureArInstantiation)