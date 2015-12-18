class PrefabConfiguration < Configuration
  class MissingVariableError < StandardError; end

  attr_accessor :journal, :name, :prefab_name

  def initialize(args = {})
    @journal = args[:journal]
    @name = args[:name]
    @prefab_name = args[:prefab_name]

    if args[:hash].is_a? Hash
      @vars = ConfigurationHash.new(args[:hash])
    else
      @vars = ConfigurationHash.new
    end

    if !@journal.nil? and !File.exists?(@journal.user.userspace_dir / 'prefabs')
      puts 'creating directory'
      Dir.mkdir @journal.user.userspace_dir / 'prefabs' if !File.exists? 'prefabs/' 
    end
  end

  def name=(name)
    if !self.name.nil? and !self.name.eql?(name)
      @old_name = self.name
    end
    @name = name
  end

  def filepath
    return nil if @journal.nil? or @name.nil?
    @journal.user.userspace_dir / 'prefabs' / "#{@name}.yml"
  end

  def load
    # Since it's possible that a config file does not yet exist, do not rely on a file at load
    begin
      super
    rescue
      @vars = ConfigurationHash.new(:customization => Prefab.skeleton(@prefab_name).config.customization) unless @prefab_name.nil?
      self
    end
  end
  
  # We only want to save the customization key of the config hash, the rest doesn't change so can be taken out of the skeleton.
  def save
    raise MissingVariableError, "@journal cannot be nil" if @journal.nil?
    raise MissingVariableError, "@name cannot be nil" if @name.nil?

    File.open(self.filepath, "w") {|f| f.write({'customization' => @vars.customization.to_hash}.to_yaml + "\n") }

    # If the name has changed, remove the old config file
    if !@old_name.nil?
      old_filepath = @journal.user.userspace_dir / 'prefabs' / "#{@old_name}.yml" 
      if File.exists? old_filepath
        File.delete(old_filepath)
        RAILS_DEFAULT_LOGGER.info "Deleted orphaned file: #{prev_filepath}"
      end
    end

    self
  end

  def reset_invalid_colors!
    return if @vars.customization.colors.nil?

    @vars.customization.colors.each do |hash_key, hash|
      default_colors = Prefab.skeleton(@prefab_name).config.customization.colors
      hash.each do |key, color|
        @vars.customization.colors[hash_key][key] = color.to_color_string.nil? ? default_colors[hash_key][key] : color.to_color_string
      end
    end
  end

  def cleanup_var_arrays!
    descriptions = Prefab.skeleton(@prefab_name).config.vars.descriptions
    return if descriptions.vars.nil?

    descriptions.vars.each do |hash_key, hash|
      if hash.is_a?(ConfigurationHash) and hash.key? "_multiple" and @vars.customization.vars[hash_key].is_a?(Array)
        @vars.customization.vars[hash_key] = @vars.customization.vars[hash_key].reject{ |val| value_is_blank_or_default(val, hash) }
      end
    end
    self
  end

private
  def value_is_blank_or_default(val, hash)
    if val.is_a?(Hash)
      val.each do |key, subvar|
        if hash[key].is_a?(ConfigurationHash) and hash[key].key? "_default"
          return true if subvar == hash[key]["_default"]
        else
          return true if subvar.nil? || subvar.blank?
        end
      end
    end

    val.nil? || val.blank?
  end
end
