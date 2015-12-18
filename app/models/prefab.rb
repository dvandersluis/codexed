class Prefab < Template 
  after_destroy :remove_config_file

  attr_reader :uses

  # Reads the template from the user's userspace and returns the contents.
  # The first time this is called, the result will be cached; subsequent calls just return the value.
  def raw_content
    unless @raw_content || !File.exists?(self.filepath)
      logger.info "Reading prefab from file: #{self.filepath}"
      @raw_content = File.read(self.filepath)
      @raw_content = replace_prefab_options(@raw_content)
    end
    @raw_content
  end
  attr_writer :raw_content

  def filepath
    Codexed.config.dirs.prefabs_dir / "#{self.prefab_name}.rhtml"
  end

  def thumbnail
    "prefabs" / "#{self.prefab_name}.png"
  end

  def default_config_path
    @config_path ||= Codexed.config.dirs.prefabs_dir / "#{self.prefab_name}.yml"
  end

  def config_i18n_override
    unless @config_i18n_override
      lang = I18n.valid_locale?(I18n.locale) ? I18n.locale.to_s : 'en'
      @config_i18n_override = Codexed.config.dirs.prefabs_dir / "#{self.prefab_name}.#{lang}.yml"
    end
    @config_i18n_override
  end

  def config_has_i18n_override?
    @config_has_i18n_override ||= File.exists? config_i18n_override 
  end

  def config
    unless @config
      journal = Journal.find(journal_id) unless journal_id.nil?
      hash = File.open(default_config_path) {|f| YAML.load(f) } if ((journal.nil? or name.nil?) and !prefab_name.nil?)

      options = {
        :journal => journal,
        :name => name,
        :prefab_name => prefab_name,
        :hash => hash
      }

      @config = PrefabConfiguration.new(options)
      @config.load unless journal.nil? or name.nil?
      
      if (journal.nil? or name.nil?) and config_has_i18n_override?
        override_options = File.open(config_i18n_override) { |f| YAML.load(f) }
        @config.deep_merge! override_options
      end
    end
    @config
  end
  
  def skeleton
    Prefab.skeleton(self.prefab_name)
  end

  def replace_prefab_options(str)
    # The deep merge allows existing prefabs to still work even if new options were added
    customization = Prefab.skeleton(self.prefab_name).config.customization.deep_merge(config.customization)

    parser = Minirus::Parser.new(str, customization) do |grammar|
      grammar.comment /\[\[!.+?\]\]/m
      grammar.expression /\[\[(\w+)?:(.+?)\]\]/m
      grammar.variable /\[\[([a-z0-9._-]+?)\]\]/
    end
    parser.parse
  end

  def convert_to_template
    template = Template.new(:journal_id => self.journal_id, :name => self.name, :raw_content => self.raw_content)
    self.destroy
    template.save
  end

  class << self
    # The Prefab skeleton is its code and metadata
    def skeleton(name = :all)
      if name == :all
        prefabs = []
        Dir.chdir(Codexed.config.dirs.prefabs_dir) do
          Dir["*.rhtml"].sort.each do |file|
            prefabs.push Prefab.new(:prefab_name => File.basename(file, ".rhtml")).find_uses
          end
        end
        prefabs
      else
        if File.exists? Codexed.config.dirs.prefabs_dir / "#{name}.rhtml"
          Prefab.new(:prefab_name => name.to_s).find_uses
        else
          nil
        end
      end
    end
  end

  def remove_config_file
    logger.info "Deleted prefab config from file: #{self.filepath}"
    File.delete(self.config.filepath) if File.exists?(self.config.filepath)
  end

  def find_uses(reload = false)
    @uses = Prefab.count(:conditions => { :prefab_name => self.prefab_name }) if !@uses or reload
    self
  end
end
