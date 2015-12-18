class DropTemplateTypes < ActiveRecord::Migration
  def self.up
    drop_table :template_types
  end

  def self.down
    create_table :template_types, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.column :key, 'char(1)', :null => false
      t.string :desc, :limit => 50, :null => false
    end
    TemplateType.create!(:key => "C", :desc => "Custom Template")
    TemplateType.create!(:key => "P", :desc => "Prefab Template")
  end
end
