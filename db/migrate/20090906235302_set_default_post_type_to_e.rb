class SetDefaultPostTypeToE < ActiveRecord::Migration
  def self.up
    change_column_default :posts, :type_id, "E"
  end

  def self.down
    change_column_default :posts, :type_id, "N"
  end
end
