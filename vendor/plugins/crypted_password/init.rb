require 'digest/sha1'
require 'crypted_password'

module SHA1Methods
  def sha1_encrypt
    Digest::SHA1.hexdigest(self)
  end

  def sha1_encrypt!
    replace(sha1_encrypt)
  end
end
String.send(:include, SHA1Methods)

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend(CryptedPassword::MacroMethods)
end

