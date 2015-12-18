class CreateInvitationCodes < ActiveRecord::Migration
  def self.up
    create_table :invitation_codes do |t|
      t.string :name, :null => false, :limit => 32
      t.integer :user_id
    end
  end

  def self.down
    drop_table :invitation_codes
  end
end
