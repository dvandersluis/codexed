class ChangeSubsEncodingToUtf8 < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE subs DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci"
    execute "ALTER TABLE subs CHANGE `name` `name` VARCHAR(20) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL"
    execute "ALTER TABLE subs CHANGE `value` `value` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL"
  end

  def self.down
    # this may not be accurate for what's on your local machine but it doesn't matter
    execute "ALTER TABLE subs DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci"
    execute "ALTER TABLE subs CHANGE `name` `name` VARCHAR(20) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL"
    execute "ALTER TABLE subs CHANGE `value` `value` VARCHAR(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL"
  end
end