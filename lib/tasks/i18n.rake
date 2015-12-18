namespace :i18n do
  desc "Find differences in keys between the existing i18n translations."
  task :compare_keys => :environment do
    hash = {}
    I18n.load_path.each do |yml|
      hash.merge!(File.open(yml) {|f| YAML.load(f) })
    end
    
    locales = hash.keys.sort!
    locale_hashes = {}
    locales.each { |locale| locale_hashes[locale.intern] = hash[locale].flatten_keys.keys }
    
    all_keys = locale_hashes.values.inject([]) { |memo, keys| memo |= keys }

    missing = {}
    locale_hashes.each do |locale, keys|
      missing[locale.to_sym] = all_keys - keys
    end
    
    result = missing.values.flatten.uniq.sort

    if !result.empty?
      # Output results
      max_length = result.max { |a, b| a.length <=> b.length }.length
      max_locale_length = locales.max { |a, b| a.length <=> b.length }.length
      
      separator = "\n" + ("-" * (max_length + 1)) + "|"
      locales.length.times { separator << ("-" * (max_locale_length + 2)) + "|" }
      separator << "\n"
      
      str = "\nKeys that do not exist in all translation sets:\n\n"
      str << (" " * max_length) + " |"
      locales.each { |locale| str << locale.to_s.center(max_locale_length + 2) + "|" }
      str << separator

      result.each do |key|
        str << "%-#{max_length}s |" % key
        locales.each do |locale|
          if missing[locale.to_sym].include? key
            str << (" " * (max_locale_length + 2)) + "|"
          else
            str << "*".center(max_locale_length + 2) + "|"
          end
        end
        str << separator
      end

      str << "* Key exists for this translation\n\n"

      puts str
    else
      puts "All translation sets have the same keys!"
    end
  end

  desc "Determine which strings in a language file are the same as those in another (and thus are possibly in need of translation))"
  task :translation_needed => :environment do
    src = ENV['SRC'] || 'en' # 
    
    if ENV['LOCALE'].nil?
      puts "i18n:translation_needed task requires a LOCALE parameter (specifies which locale to check)."
      exit
    end
    locale = ENV['LOCALE'] 

    source_strings = File.open(RAILS_ROOT / 'config/locales' / "#{src}.yml") {|f| YAML.load(f) }[src].flatten_keys
    locale_strings = File.open(RAILS_ROOT / 'config/locales' / "#{locale}.yml") {|f| YAML.load(f) }[locale].flatten_keys

    result = {}

    puts "Comparing locale #{locale} to #{src}."
    locale_strings.each do |key, string|
      if locale_strings[key] == source_strings[key]
        result[key] = string
      end
    end

    puts result.expand_keys.to_yaml
  end
end
