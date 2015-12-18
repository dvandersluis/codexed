class AddTemplates < ActiveRecord::Migration
  def self.up
    create_table :templates, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer :journal_id, :null => false
      t.string :name, :limit => 40, :null => false
      t.datetime :created_at, :null => false
      t.datetime :updated_at, :null => false
    end
    add_column :entries, :template_id, :integer, :after => :journal_id, :null => true
    add_column :journals, :default_template_id, :integer, :after => :title, :null => true
  end
  def self.down
    drop_table :templates
    remove_column :entries, :template_id
    remove_column :journals, :default_template_id
  end
end
