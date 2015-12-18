class CodexedI18n < I18n::Backend::Simple
  # Augment translate to try the key in the general scope if the key doesn't exist in the given scope.
  def translate(locale, key, options = {})
    raise InvalidLocale.new(locale) if locale.nil?
    return key.map { |k| translate(locale, k, options) } if key.is_a? Array

    reserved = :scope, :default
    count, scope, default = options.values_at(:count, *reserved)
    options.delete(:default)
    values = options.reject { |name, value| reserved.include?(name) }

    entry = lookup(locale, key, scope)
    if entry.nil?
      # If the given key starts with general, no need to try to look it up twice
      entry = lookup(locale, key, 'general') unless key_to_a(key).first == :general
      if entry.nil?
        entry = default(locale, default, options)
        if entry.nil?
          raise(I18n::MissingTranslationData.new(locale, key, options))
        end
      end
    end
    entry = pluralize(locale, entry, count)
    entry = interpolate(locale, entry, values)
    entry
  end

  # Augment lookup to search up the hierarchy for a key
  def lookup(locale, key, scope = [])
    return unless key
    init_translations unless initialized?
    
    key_array = key_to_a(key)
    keys = I18n.send(:normalize_translation_keys, locale, key, scope)

    while keys.length > key_array.length do
      string = keys.inject(translations) do |result, k|
        if (x = result[k.to_sym]).nil?
          break
        else
          x
        end
      end
      return string if !string.nil?
      keys.delete_at(-(key_array.length + 1))
    end
    return nil
  end

private
  # Convert a key to an array of component symbols
  def key_to_a(key)
    [key].map { |k| k.to_s.split(/\./) }.flatten.map { |k| k.to_sym }
  end
end

I18n.backend = CodexedI18n.new

module I18n
  class << self
    def valid_locale?(lang)
      available_locales.include? lang.to_sym
    end

    def base_locale
      locale.to_s.split("-").first.to_sym
    end
    
    # Extension to let the models that include HasStrings reload when the locale is changed
    def locale_with_reload_strings=(locale)
      self.locale_without_reload_strings = locale
      Language.reload_strings!
      Country.reload_strings!
    end
    
    alias_method_chain :locale=, :reload_strings
  end
end

module I18nModelExtension
  # For models, t will guess the scope if not given
  def t(key, options = {})
    if self.respond_to? :class_name
      scope = 'models.' + self.class_name.downcase
    else
      scope = 'models.' + self.class.to_s.
        # this is exactly like AS::Inflector.underscore, except '::' -> '.' not '/'
        gsub(/::/, '.').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end

    options[:scope] = scope unless options.include? :scope
    I18n.translate(key, options)
  end
end

module I18nControllerExtension
  include ActionView::Helpers::TagHelper

  # For controllers, t will guess the scope if not given
  def t(key, options = {})
    # The controller scope is generated from the path, but can be overridden by specifying @controller_scope in the class
    scope = 'controllers.' + (self.controller_scope || self.controller_path.split('/').join('.'))
    scope += '.' + self.action_name if self.respond_to? :action_name and !self.action_name.nil?
    
    options[:scope] = scope unless options.include? :scope
    options[:raise] = true
    I18n.translate(key, options)
  rescue I18n::MissingTranslationData => e
    keys = I18n.send(:normalize_translation_keys, e.locale, e.key, e.options[:scope])
    content_tag('span', keys.join(', '), :class => 'translation_missing')
  end
end

module I18nViewExtension
  # Add the ability to create a block in which a scope applies
  def t(key, options = {})
    options[:scope] = @scope unless options.include? :scope
    translate(key, options)
  end
  
  def t_scope(*args)
    if args.delete(:append) and !@scope.nil?
      old_scope, @scope = @scope, @scope + args
    else
      old_scope, @scope = @scope, args
    end

    ret, @scope = yield, old_scope
    ret
  end
end

ActiveRecord::Base.send :include, I18nModelExtension
ActiveRecord::Base.class_eval { extend I18nModelExtension }
ActionController::Base.send :include, I18nControllerExtension
ActionController::Base.class_eval do
  extend I18nControllerExtension

  class << self
    attr_reader :controller_scope
  end

  def controller_scope; self.class.controller_scope; end;
end
ActionView::Base.send :include, I18nViewExtension
