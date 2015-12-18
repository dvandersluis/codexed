#=== Obligatory RSpec require stuff ===

gem 'test-unit', '1.2.3' if RUBY_VERSION.to_f >= 1.9
rspec_gem_dir = nil
Dir["#{RAILS_ROOT}/vendor/gems/*"].each do |subdir|
  rspec_gem_dir = subdir if subdir.gsub("#{RAILS_ROOT}/vendor/gems/","") =~ /^(\w+-)?rspec-(\d+)/ && File.exist?("#{subdir}/lib/spec/rake/spectask.rb")
end
rspec_plugin_dir = File.expand_path(File.dirname(__FILE__) + '/../../vendor/plugins/rspec')

if rspec_gem_dir && (test ?d, rspec_plugin_dir)
  raise "\n#{'*'*50}\nYou have rspec installed in both vendor/gems and vendor/plugins\nPlease pick one and dispose of the other.\n#{'*'*50}\n\n"
end

if rspec_gem_dir
  $LOAD_PATH.unshift("#{rspec_gem_dir}/lib")
elsif File.exist?(rspec_plugin_dir)
  $LOAD_PATH.unshift("#{rspec_plugin_dir}/lib")
end

# Don't load rspec if running "rake gems:*"
unless ARGV.any? {|a| a =~ /^gems/}

begin
  require 'spec/rake/spectask'
rescue MissingSourceFile
  module Spec
    module Rake
      class SpecTask
        def initialize(name)
          task name do
            # if rspec-rails is a configured gem, this will output helpful material and exit ...
            require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")

            # ... otherwise, do this:
            raise <<-MSG

#{"*" * 80}
*  You are trying to run an rspec rake task defined in
*  #{__FILE__},
*  but rspec can not be found in vendor/gems, vendor/plugins or system gems.
#{"*" * 80}
MSG
          end
        end
      end
    end
  end
end

Rake.application.instance_variable_get('@tasks').delete('default')

#=== With that out of the way ;) ===

namespace :papyrus do
  def spec_options(env)
    arr = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
    arr += ['--example', env["EXAMPLE"]] if env["EXAMPLE"]
    arr += ['--line', env["LINE"]] if env["LINE"]
    arr
  end
  
  desc "Run all Papyrus specs"
  Spec::Rake::SpecTask.new(:spec) do |t|
    t.spec_opts = spec_options(ENV)
    t.spec_files = FileList['spec/papyrus/**/*_spec.rb']
  end
  
  namespace :spec do
    desc "Run Papyrus unit specs"
    Spec::Rake::SpecTask.new(:unit) do |t|
      t.spec_opts = spec_options(ENV)
      t.spec_files = FileList['spec/papyrus/unit/**/*_spec.rb']
    end
    
    desc "Run Papyrus acceptance specs"
    Spec::Rake::SpecTask.new(:acceptance) do |t|
      t.spec_opts = spec_options(ENV)
      t.spec_files = FileList['spec/papyrus/acceptance/**/*_spec.rb']
    end
  end
end

end