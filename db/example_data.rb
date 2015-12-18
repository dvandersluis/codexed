module FixtureReplacement
  
  # For each type of record given here, there are two states represented.
  # The first is the basic representation of the record. All the essential fields are
  #  filled in except those which callbacks will ultimately fill in at the time of creation.
  #  Hence, the record is not necessarily in a valid state until after it is saved for the
  #  first time.
  # The second is a fuller representation of the record. The essential fields are filled in
  #  in order for the record to validate correctly.
  # When using records that will never be saved (such as when working with validations)
  #  you want to use the 'full' version. Otherwise, you probably want to use the basic version.
  # The 'typical' version was supposed to represent a preexisting record, but is not being
  #  used currently.
  
  attributes_for :entry_type do |t|
    t.code = "N"
    t.desc = "Normal Entry"
  end
  
  attributes_for :user do |u|
    u.username = "john"
    u.password = "secret"
    u.first_name = "John"
    u.last_name = "Smith"
    u.email = "john@smith.com"
    u.invitation_code = default_invitation_code
  end
  attributes_for :typical_user, :from => :user do |u|
    u.salt = String.random
    u.mnemonic = String.random
    u.activation_key = String.random
    u.activated_at = Time.now
    u.activation_email_sent_at = Time.now
  end
  
  attributes_for :journal do |j|
    j.user = default_user
    j.title = "The Journal of John"
  end
  attributes_for :typical_journal do |j|
  end
  
  attributes_for :template do |t|
    t.journal = default_journal
    t.name = "main"
  end
  attributes_for :typical_template do |j|
  end
  
  attributes_for :entry do |e|
    e.journal = default_journal
    e.title   = "Sample Entry"
  end
  attributes_for :normal_entry, :from => :entry do |e|
    e.type_id = "N"
  end
  attributes_for :special_entry, :from => :entry do |e|
    e.type_id = "S"
  end
  attributes_for :random_normal_entry, :from => :normal_entry do |e|
    e.title = String.random(10)
    e.created_at = Time.random
  end
  attributes_for :normal_entry_with_time, :from => :normal_entry do |e|
    e.created_at = Time.now
    e.posted_at = Time.now
  end
  attributes_for :special_entry_with_time, :from => :special_entry do |e|
    e.created_at = Time.now
    e.posted_at = Time.now
  end
  attributes_for :full_normal_entry, :from => :normal_entry_with_time do |e|
    e.permaname = "sample-entry"
  end
  attributes_for :full_special_entry, :from => :special_entry_with_time do |e|
    e.permaname = "sample-entry"
  end
  
  attributes_for :sub do |s|
    s.journal = default_journal
    s.name = "michael"
    s.value = "jackson"
  end
  attributes_for :typical_sub do |j|
  end
  
  attributes_for :invitation_code do |c|
    c.name = "xxx"
    c.user_id = nil
    c.email_address = 'john@smith.com'
  end
  attributes_for :typical_invitation_code do |c|
  end
end

#module Factory
#  include Singleton
#  include FixtureReplacement
#end
