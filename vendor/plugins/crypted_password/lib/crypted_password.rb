module CryptedPassword
  module MacroMethods
    def crypted_password(*columns)
      columns.each do |column|
        options = { :current_column => column }
        write_inheritable_hash :crypted_password_options, options
        class_inheritable_reader :crypted_password_options
        extend(ClassMethods)
      end

      include InstanceMethods
    end
  end

  module ClassMethods
    def self.extended(klass)
      column = klass.crypted_password_options[:current_column].to_s
      klass.class_eval %Q{
        attr_accessor :#{column}, :#{column}_confirmation

        validates_presence_of :#{column}, :if => Proc.new {|obj| obj.#{column}.blank? and obj.password_required? :#{column} }
        validates_length_of :#{column}, :if => Proc.new {|obj| !obj.#{column}.blank? }, :within => 4..20
        validates_confirmation_of :#{column}, :if => Proc.new {|obj| !obj.#{column}.blank? and obj.validate_presence_of_password_confirmation? :#{column}}
        validates_presence_of :#{column}_confirmation, :if => Proc.new {|obj| obj.validate_presence_of_password_confirmation? :#{column} }

        before_save :encrypt_#{column}

        def encrypt_#{column}
          return if #{column}.blank?
          self.crypted_#{column} = self.#{column}.sha1_encrypt
        end

        def #{column}_authenticates?(password)
          return false if password.nil? or password.blank?
          self.crypted_#{column} == password.sha1_encrypt
        end
      }
    end
  end

  module InstanceMethods
    def password_required?(column) 
      @password_required and @password_required[column]
    end

    def password_required!(column) 
      @password_required = {} if @password_required.nil?
      @password_required[column] = true
    end

    def password_authenticates?(options = {})
      options.each_pair do |key, value|
        if defined?(self["crypted_" + key])
          return true if self.send(key.to_s + "_authenticates?", value)
        end
      end

      false
    end

    def validate_presence_of_password_confirmation?(column)
      @validate_presence_of_password_confirmation and @validate_presence_of_password_confirmation[column]
    end

    def validate_presence_of_password_confirmation!(column)
      @validate_presence_of_password_confirmation = {} if @validate_presence_of_password_confirmation.nil?
      @validate_presence_of_password_confirmation[column] = true
    end  
  end
end
