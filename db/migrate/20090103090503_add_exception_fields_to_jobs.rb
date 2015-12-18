class AddExceptionFieldsToJobs < ActiveRecord::Migration
  def self.up
    add_column :jobs, :exception_class, :string, :after => :result
    add_column :jobs, :exception_message, :string, :after => :exception_class
    add_column :jobs, :exception_backtrace, :text, :after => :exception_message
  end

  def self.down
    remove_column :jobs, :exception_backtrace
    remove_column :jobs, :exception_message
    remove_column :jobs, :exception_class
  end
end
