# Fix validates_confirmation_of so error is put on the confirmation field,
# not the original field, where it really belongs.
module ActiveRecord
  class Base
    def self.validates_confirmation_of(*attr_names)
      configuration = { :on => :save }
      configuration.update(attr_names.extract_options!)

      attr_accessor(*(attr_names.map { |n| "#{n}_confirmation" }))

      validates_each(attr_names, configuration) do |record, attr_name, value|
        unless record.send("#{attr_name}_confirmation").nil? || value == record.send("#{attr_name}_confirmation")
          record.errors.add("#{attr_name}_confirmation", :no_match, :value => attr_name.to_s.downcase, :default => configuration[:message]) 
        end
      end
    end
  end
end
