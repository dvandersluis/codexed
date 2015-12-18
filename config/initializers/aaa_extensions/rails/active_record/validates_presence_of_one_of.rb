module ActiveRecord
  class Base
    def self.validates_presence_of_one_of(*attr_names)
      configuration = { :on => :save }
      configuration.update(attr_names.extract_options!)

      # can't use validates_each here, because it cannot cope with nonexistent attributes,
      # while errors.add_on_empty can
      send(validation_method(configuration[:on]), configuration) do |record|
        record.errors.add_on_all_blank(attr_names, configuration[:message])
      end
    end
  end

  class Errors
    def add_on_all_blank(attributes, custom_message = nil)
      all_blank = true
      for attr in [attributes].flatten
        value = @base.respond_to?(attr.to_s) ? @base.send(attr.to_s) : @base[attr.to_s]
        all_blank = false and break if !value.blank?
      end

      if all_blank
        if attributes.length > 1
          other_attrs = ""
          other_attrs << "and " + attributes[1..-2].map{|a| @base.class.human_attribute_name(a).downcase}.join(", ") + " " if attributes.length > 2
          other_attrs << "and #{@base.class.human_attribute_name(attributes[-1].to_s).downcase}"
          quantifier = attributes.length == 2 ? 'both' : 'all' 
          add(attributes[0], :all_blank, :default => custom_message, :other_attrs => other_attrs, :quantifier => quantifier)
        else
          add(attributes, :blank, :default => custom_message)
        end
      end
    end
  end
end
