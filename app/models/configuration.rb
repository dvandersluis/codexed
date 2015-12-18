# This class is used to hold configuration variables for a user's journal.
# When a Config instance is created, the YAML file that holds the variables
# (located in the user's userspace) is converted into a hash (which it was stored in),
# which is then converted to a multilevel openhash. This not only makes it possible
# to group configuration variables, but to also use dot-notation to access the variables
# themselves (similar to how Mozilla stores its configuration variables). So instead
# of saying something like this:
#
#   if journal.config['formatting']['nl2br']
#     # ...
#   end
#
# you can say:
#
#   if journal.config.formatting.nl2br? 
#     # ...
#   end
#
# To set a config variable, just do:
#
#   journal.config.formatting.nl2br = true
#
# And saving the config vars to file is just a matter of doing:
#
#   journal.config.save
#

#require 'configuration_hash'

class Configuration
  
  attr_reader :vars
  
  def initialize(journal)
    @journal = journal
    @vars = ConfigurationHash.new
    path = self.filepath
    unless File.exists?(path)
      # copy the skeleton config file
      # TODO do this when the user is created, for performance
      FileUtils.cp(Codexed.config.dirs.skel_dir/'config.yml', path)
    end
  end
  
  def filepath
    @journal.user.userspace_dir / 'config.yml'
  end
  
  # Serializes the configuration hash in YAML format, then writes it to file.
  def save
    File.open(self.filepath, "w") {|f| f.write(@vars.to_hash.to_yaml + "\n") }
    self
  end
  
  # Reads the data from the config file, converts the YAML back into a hash.
  def load
    hash = File.open(self.filepath) {|f| YAML.load(f) }
    @vars = ConfigurationHash.new(hash)
    self
  end
  
  # delegate missing methods to @vars
  def method_missing(name, *args)
    @vars.send(name, *args)
  end

  def reset_keys(*keys)
    return if keys.empty?
    
    hash = ConfigurationHash.new(File.open(Codexed.config.dirs.skel_dir / 'config.yml') {|f| YAML.load(f) })
    keys.each { |k| @vars.subtract_keys!(k) }
    @vars = hash.deep_merge(@vars)
  end

end
