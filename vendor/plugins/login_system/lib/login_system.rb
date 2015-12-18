require 'openssl'
require 'digest/sha1'

module LostInCode
  module LoginSystem
    
    REQUIRED_FIELDS = %w(username crypted_password salt mnemonic)
    REQUIRED_FIELDS_TEXT = "
  - username (string not null)
  - crypted_password (string 255 not null)
  - salt (string 255 not null)
  - mnemonic (string 255 null)
"
    
    module MacroMethods
      #
      # Imports the authentication methods into the model.
      # Also automatically adds validations.
      # Pass :mnemonic_tokens => [ ... ] to specify which fields should be used
      #  to create the mnemonic (stored in the cookie).
      #
      def participates_in_login_system(options=nil)
        options ||= { :mnemonic_tokens => [] }
        write_inheritable_hash :login_participation_options, options
        #check_table_exists
        #check_login_fields_exist
        extend(ClassMethods)
        class_inheritable_reader :login_participation_options
        include InstanceMethods
      end
    private
      def check_table_exists
        unless connection.tables.include?(table_name)
          raise <<-EOT
Error initializing login_system plugin:
The #{table_name} table needs to exist!
Make sure it has these fields: #{REQUIRED_FIELDS_TEXT}
          EOT
        end
      end
      def check_login_fields_exist
        unless (REQUIRED_FIELDS - column_names).empty?
          raise <<-EOT
Error initializing login_system plugin:
The #{table_name} table needs to have these fields defined: #{REQUIRED_FIELDS_TEXT}
          EOT
        end
      end
    end
    
    module ClassMethods
      def self.extended(klass)
        klass.class_eval do
          before_validation_on_create :set_salt_and_encrypt_password
          
          validates_presence_of     :username#, :crypted_password, :salt
          validates_presence_of     :password,                   :if => Proc.new {|u| u.crypted_password.blank? }
          validates_length_of       :password, :within => 4..20, :if => Proc.new {|u| !u.password.blank? }
          validates_confirmation_of :password,                   :if => Proc.new {|u| !(u.password.blank? or u.password_confirmation.blank?) }
          validates_presence_of     :password_confirmation,      :if => Proc.new {|u| u.validate_presence_of_password_confirmation? }
          
          attr_accessor :password, :password_confirmation
        end
      end
      # Authenticates a user by their username name and unencrypted password.
      # Returns the user or nil.
      def authenticate(username, password)
        user = find_by_username(username)
        user && user.authenticates_against?(password) ? user : nil
      end
      def encrypt_password_using_salt(password, salt)
        encrypt("--#{salt}--#{password}--")
      end
    private
      def encrypt(something)
        Digest::SHA1.hexdigest(something)
      end
    end # ClassMethods
    
    module InstanceMethods
      # Returns whether or not the given password matches against the stored encrypted password.
      def authenticates_against?(password)
        self.crypted_password == encrypt_using_salt(password)
      end
      # Sets a string that will be used to store the user in the cookie.
      # It is based off the current time so as to foil brute-force attacks.  
      def set_mnemonic
        self.mnemonic = encrypt_using_salt(generated_mnemonic)
      end
      def set_mnemonic!
        set_mnemonic
        save!
      end
      def clear_mnemonic
        self.mnemonic = nil
      end
      def clear_mnemonic!
        clear_mnemonic
        save!
      end
      def reencrypt_password!
        encrypt_password
        save!
      end
      
      def validate_presence_of_password_confirmation?
        @validate_presence_of_password_confirmation
      end
      def validate_presence_of_password_confirmation!
        @validate_presence_of_password_confirmation = true
      end
      
    private
      def generated_mnemonic
        mnemonic_tokens = [ Time.now.to_i, self.crypted_password ]
        for attr in login_participation_options[:mnemonic_tokens]
          mnemonic_tokens << self.send(attr) if self.respond_to?(attr)
        end
        "--" + mnemonic_tokens.join('--') + "--"
      end
      # called before validation (on create)
      def set_salt_and_encrypt_password
        set_salt
        encrypt_password
      end
      def set_salt
        hash = OpenSSL::Digest::MD4.hexdigest(rand.to_s)
        # the salt will never change
        self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_i}--#{hash}--")
      end
      def encrypt_password
        return if @password.blank?
        self.crypted_password = encrypt_using_salt(@password)
      end
      def encrypt_using_salt(something)
        self.class.encrypt_password_using_salt(something, self.salt)
      end
    end
    
  end
end
