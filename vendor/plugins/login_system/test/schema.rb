ActiveRecord::Schema.define(:version => 1) do
  create_table :users do |t|
    t.string :username,         :limit => 255, :null => false
    t.string :crypted_password, :limit => 255, :null => false
    t.string :salt,             :limit => 255
    t.string :mnemonic,         :limit => 255
  end
end