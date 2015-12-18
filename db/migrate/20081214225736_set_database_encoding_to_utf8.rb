class SetDatabaseEncodingToUtf8 < ActiveRecord::Migration
  def self.up
    execute "ALTER DATABASE #{current_database} CHARSET utf8 COLLATE utf8_general_ci"
  end

  def self.down
    # pma specific settings on server
    execute "ALTER DATABASE #{current_database} CHARSET latin1 COLLATE latin_swedish_ci"
  end
end
