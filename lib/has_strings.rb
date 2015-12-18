module HasStrings
  def self.included(klass)
    klass.extend ClassMethods
  end

  def name
    @name ||= self.class.strings[id]
  end
  
  def ascii_name
    name.uninternationalize
  end

  module ClassMethods
    def strings
      Thread.current["#{self.name}_strings"] ||= reload_strings! 
    end

    def reload_strings!
      Thread.current["#{self.name}_strings"] = 
        begin
          File.open(RAILS_ROOT / 'config' / 'locales' / self.name.pluralize.downcase / I18n.locale.to_s + ".yml") { |f| YAML.load(f) }
        rescue Errno::ENOENT
          # Load the English strings if the current language doesn't have a strings file
          File.open(RAILS_ROOT / 'config' / 'locales' / self.name.pluralize.downcase / 'en.yml') { |f| YAML.load(f) }
        end
    end

    # Provides an array for using with a select helper to build a selectbox for the model
    # If a block is given and doesn't yield nil, its return will be used the option text.
    def collection_for_select(collection)
      collection.flatten.map{|obj| desc = yield obj if block_given?; [desc || self.strings[obj.id], obj.id]}
    end
  end
end
