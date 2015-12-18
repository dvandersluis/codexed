# Base Codexed configuration
Codexed.configure do |config|
  config.base do |base|
    base.dirs.userspace_root     = Proc.new {|dirs| dirs.users_dir                   }
    base.dirs.fake_entries_dir   = Proc.new {|dirs| dirs.data_dir  / 'fake_entries'   }
    base.dirs.fake_templates_dir = Proc.new {|dirs| dirs.data_dir  / 'fake_templates' }
    base.dirs.skel_dir           = Proc.new {|dirs| dirs.data_dir  / 'skel'           }
    base.dirs.prefabs_dir        = Proc.new {|dirs| dirs.data_dir / 'prefabs'        }
  end
end

# Load all the environment-level config files at once
environments = File.open(RAILS_ROOT / 'config' / 'database.yml') {|f| YAML.load(f) }
for env in environments.keys.sort
  config = Codexed.config(env)
  filename = RAILS_ROOT / 'config' / 'codexed' / "#{env}.rb"
  next unless File.exists?(filename)
  contents = File.read(filename)
  eval(contents, binding, filename)
end

Codexed.autocreate_config_dirs unless RAILS_ENV == 'test'
