class CreateJobs < ActiveRecord::Migration
  def self.up
    create_table :jobs do |t|
      t.string  :worker_class
      t.string  :worker_method
      
      t.text    :args
      t.text    :result

      t.integer :priority

      t.integer :progress
      t.string  :state
      
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :jobs, :state
  end

  def self.down
    drop_table :jobs
  end
end
