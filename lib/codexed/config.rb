require 'ropenhash_with_block'

# Everything related to Codexed configuration is in its own module
module Codexed
  class << self
    attr_accessor :base_domain  # Instead of hard coding the domain, keep track of what it is.
                                # Set by ApplicationController

    def config(env=nil)
      env ||= RAILS_ENV
      real_config[env] ||= real_config[:base].deep_clone
      real_config[env]
    end
    def configure
      yield(real_config)
    end
    def real_config
      @config ||= ROpenHashWithBlock.new
    end
    
    def autocreate_config_dirs
      # probably doesn't belong here but it works
      if RAILS_ENV == 'test'
        # copy data to test/data
        data1 = Codexed.config(:development).dirs.data_dir
        data2 = Codexed.config.dirs.data_dir
        #FileUtils.cp_r option :remove_destination not available in 1.8.5
        #FileUtils.cp_r(etc1, etc2, :remove_destination => true)
        FileUtils.rm_r(data2) if File.exists?(data2)
        FileUtils.cp_r(data1, data2)
        #puts "** Copied #{etc1} to #{etc2}."
      end
  
      Codexed.config.dirs.each_key do |k|
        dir = Codexed.config.dirs[k]
        FileUtils.mkdir_p(dir)
        #puts "** Created dir #{dir}."
      end
    end

    def remove_config_dirs
      Codexed.config.dirs.each_key do |k|
        dir = Codexed.config.dirs[k]
        FileUtils.rm_rf(dir)
        #puts "** Removed dir #{dir}."
      end
    end

    # Change to true to close Codexed and redirect all actions to /main/closed
    def closed?
      false
    end

    def april_fools?(year=nil)
      year = Time.zone.today.year if year.nil?
      Date.today == Time.local(year, 4, 1).to_date
    end
  end
end
