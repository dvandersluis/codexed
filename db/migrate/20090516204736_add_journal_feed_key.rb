class AddJournalFeedKey < ActiveRecord::Migration
  def self.up
    add_column :journals, :feed_key, :string, :limit => 13, :after => :export_job_id
    add_index :journals, :feed_key, :unique => true
    
    puts "Generating feed keys:"
    Journal.reset_column_information
    Journal.transaction do
      Journal.find_each(:include => :user, :batch_size => 100) do |journal|
        journal.generate_feed_key
        journal.save!
        puts "  - #{journal.user.username}"
      end
    end
  end

  def self.down
    remove_index :journals, :column => :feed_key
    remove_column :journals, :feed_key
  end
end
