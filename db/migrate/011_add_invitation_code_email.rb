class AddInvitationCodeEmail < ActiveRecord::Migration
  def self.up
	add_column :invitation_codes, :email_address, :string, :limit => 50, :null => false, :after => :user_id
  end

  def self.down
	remove_column :invitation_codes, :email_address
  end
end
