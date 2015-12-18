class SetEntryAndTemplateBodyToEmptyStringByDefault < ActiveRecord::Migration
  def self.up
    change_column_default :entries, :raw_body, ""
    change_column_default :templates, :raw_content, ""
  end

  def self.down
    change_column_default :templates, :raw_content, nil
    change_column_default :entries, :raw_body, nil
  end
end
