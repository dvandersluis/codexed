class RenameCustomCreatedAtToPostedAt < ActiveRecord::Migration
  def self.up
    rename_column :entries, :custom_created_at, :posted_at
  end

  def self.down
    rename_column :entries, :posted_at, :custom_created_at
  end
end
