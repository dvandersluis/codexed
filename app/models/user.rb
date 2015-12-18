# == Schema Information
# Schema version: 20080712010244
#
# Table name: users
#
#  id                       :integer(11)     not null, primary key
#  username                 :string(30)      default(""), not null
#  crypted_password         :string(255)     default(""), not null
#  salt                     :string(255)     default(""), not null
#  mnemonic                 :string(255)     
#  first_name               :string(50)      default(""), not null
#  last_name                :string(50)      default(""), not null
#  display_name             :string(50)      
#  email                    :string(50)      
#  gender                   :string(1)       
#  activation_key           :string(255)     default(""), not null
#  admin                    :boolean(1)      
#  reset_password_key       :string(7)       
#  ancient                  :boolean(1)      not null
#  created_at               :datetime        not null
#  updated_at               :datetime        not null
#  activated_at             :datetime        
#  activation_email_sent_at :datetime        
#

#unless $FOCUSED_TEST
#  require 'codexed/rails_ext'  # new validates_format_of
#  require 'codexed/validates_email'
#end

class User < ActiveRecord::Base
  
  USERNAME_PATTERN = "[\\w-]+"
  DISALLOWED_USERNAMES = %w( admin ads alpha api automailer beta blog bugs dev devforums devwiki diary forum forums help images iphone journal login logout m mail members mobile mods mysql new noreply old options phpmyadmin postmaster public redmine test secure src static super_admin support svn wiki writing )
  
  participates_in_login_system if defined?(LostInCode::LoginSystem)
  
  attr_accessor :current_password
  attr_accessor :invitation_code_name
  attr_boolean :validate_invitation_code_email
  attr_uniquely_generated(:guid, :on => :create) { String.random(13) }
  attr_uniquely_generated(:activation_key, :on => :create) { String.random(7) }
  
  # Associations
  
  has_one   :journal, :dependent => :destroy
  has_one   :invitation_code, :dependent => :nullify
  has_many  :user_favorites, :dependent => :destroy
  has_many  :favorite_journals, :through => :user_favorites, :source => :journal, :include => :user
  has_many  :favorite_journal_posts, :through => :favorite_journals, :source => :posts, :include => { :journal => :user }

  # Validations
  
  validates_length_of       :username, :in => 3..30, :allow_blank => true
  validates_exclusion_of    :username, :in => DISALLOWED_USERNAMES, :on => :create, :allow_blank => true
  validates_format_of       :username, :with => /^#{USERNAME_PATTERN}$/, :message => :username_valid_chars, :allow_blank => true
  # in case we ever have a use for load balancing, disallow "www" and "www#" where # is any number
  validates_format_of	      :username, :not => /^www\d*$/, :message => :reserved, :allow_blank => true
  validates_uniqueness_of   :username, :case_sensitive => false
    
  validates_length_of       :first_name, :maximum => 50, :allow_blank => true
  validates_length_of       :last_name, :maximum => 50, :allow_nil => true
  validates_length_of       :display_name, :maximum => 50, :allow_nil => true
  
  validates_email           :email, :message => :email, :allow_blank => true
  validates_presence_of     :email
  validates_length_of       :email, :maximum => 50, :allow_blank => true
  
  validates_acceptance_of :tos, :message => :acceptance_of_tos
  validates_acceptance_of :prerelease_tos, :message => :acceptance_of_prerelease_tos
  
  validate :birthday_must_be_valid_datestamp
  validate :username_must_contain_at_least_three_alphanumerics
  validate :invitation_code_should_exist
  validate :invitation_code_should_be_unused
  validate :given_email_should_match_address_invitation_code_was_sent_to, :if => :validate_invitation_code_email?
  
  # Filters
  
  before_validation :put_together_birthday
  before_create     :generate_activation_key
  after_create      :make_directories
  after_create      :create_default_journal!
  after_create      :save_invitation_code
  before_destroy    :remove_root_directory
  
  # Scopes
  
  default_scope :include => :journal
  
  # Actions
  
  def create_default_journal!
    Journal.create!(:user => self, :title => "#{self.username}'s Journal")
  end
  
  def activate!
    self.activated_at = Time.now
    self.save!
  end
  def activated?
    !self.activated_at.nil?
  end
  
  def invitation_code_name=(name)
    @invitation_code_name = name
    if code = InvitationCode.find_by_name(@invitation_code_name)
      code.user = self
      self.invitation_code = code   # we shouldn't have to do this, but whatever
    end
  end

  def rename!(name)
    # Change a user's username
    # This affects the users.username, user_favorites.display_name and the users directory

    return false if name.nil? or name.blank?

    if User.exists?(['username = ?', name])
      user = User.find_by_username(name)
      return false if user != self
    end

    old_path = self.userspace_dir
    new_path = Codexed.config.dirs.userspace_root / name[0..1]

    FileUtils.mkdir_p new_path unless File.exists? new_path
    User.transaction do
      self.username = name
      self.save!

      UserFavorite.update_all(["display_name = ?", name], ["display_name = ?", self.username])

      FileUtils.mv old_path, new_path / name
    end
  end
  
  def change_password(current, new, confirm)
    if self.authenticates_against? current
      if new.blank? or confirm.blank?
        raise ArgumentError, t(:new_password_blank)
      else
        self.attributes = attributes.merge({ 'password' => new, 'password_confirmation' => confirm })
        if self.valid?
          encrypt_password
          return true
        elsif (e = self.errors.on(:password_confirmation)) && e.include?(t(:no_match, :scope => 'activerecord.errors.messages', :value => "password"))
          self.errors.clear
          raise ArgumentError, t(:new_password_mismatch)
        end
      end
    else
      raise ArgumentError, t(:incorrect_password)
    end
  end

  def change_password!(current, new, confirm)
    if change_password(current, new, confirm)
      self.save!
    end
  end
  
  # Pseudo-attributes
  
  def login_name
    #[first_name, username].find {|v| !v.blank? }
    username
  end
  
  def full_name
    [first_name, last_name].reject {|name| name.blank? }.join(" ")
  end
  
  def journal_id
    # hack to get corresponding journal id without instantiating Journal
    connection.select_value(sanitize_sql(["SELECT id FROM journals WHERE user_id = ?", self.id])).to_i
  end

  def ordered_user_favorites
    UserFavorite.find_by_sql "SELECT fj.*
      FROM journals AS j
      RIGHT JOIN user_favorites AS fj
        ON fj.journal_id = j.id
      LEFT JOIN posts AS p
        ON p.id = j.current_entry_id
      WHERE fj.user_id = #{id}
      ORDER BY j.id IS NULL, p.created_at DESC, fj.display_name ASC"
  end

  # Paths
  
  def userspace_dir
    Codexed.config.dirs.userspace_root / username[0..1] / username
  end
  
  def entries_dir
    userspace_dir / "entries"
  end
  
  def templates_dir
    userspace_dir / "templates"
  end

  def prefabs_dir
    userspace_dir / "prefabs"
  end
  
  #def remove_password_confirmation_error_if_necessary
  #  if self.password_confirmation.blank? && (errors = raw_errors['password'])
  #    errors.delete("doesn't match confirmation")
  #  end
  #end
  #def remove_email_confirmation_error_if_necessary
  #  if self.email_confirmation.blank? && (errors = raw_errors['email'])
  #    errors.delete("doesn't match confirmation")
  #  end
  #end
  
  #=== Birthday stuff ===
  
  attr_writer :birthday_month, :birthday_day, :birthday_year
  
  def birthday_month
    @birthday_month ||= birthday.andand.strftime('%m')
  end
  def birthday_day
    @birthday_day ||= birthday.andand.strftime('%d')
  end  
  def birthday_year
    @birthday_year ||= birthday.andand.strftime('%Y')
  end

  class << self
    def birthdays_in(month, start_day = nil, end_day = nil)
      conditions = [["journals.listed = 1 AND list_birthday = 1 AND birthday IS NOT NULL AND MONTH(birthday) = ?", month]]
      conditions << ["DAY(birthday) >= ?", start_day] unless start_day.nil?
      conditions << ["DAY(birthday) <= ?", end_day] unless end_day.nil?

      users = all(:select => "users.id, username, birthday, show_age", :include => :journal,
          :conditions => [conditions.collect(&:first).join(" AND "), *conditions.collect(&:last)],
          :order => "MONTH(birthday) ASC, DAY(birthday) ASC, username ASC"
         )

      # Group birthdays by day
      users.inject(Hash.new) do |memo, user|
        day = user.birthday.day
        memo[day] = [] unless memo[day]
        memo[day] << user
        memo
      end
    end

    def find_upcoming_birthdays(max = 10, distance = 3)
      users = User.find_by_sql [%Q(
        SELECT * 
        FROM (
          SELECT CASE
            WHEN DATE(CONCAT(YEAR(:now), '-', MONTH(u.birthday), '-', DAY(u.birthday))) < :today
            THEN DATE(CONCAT(YEAR(:now), '-', MONTH(u.birthday), '-', DAY(u.birthday))) + INTERVAL 1 YEAR
            ELSE DATE(CONCAT(YEAR(:now), '-', MONTH(u.birthday), '-', DAY(u.birthday)))
            END AS next_birthday, u.*
          FROM users AS u
          JOIN journals AS j
            ON j.user_id = u.id
          WHERE u.birthday IS NOT NULL
            AND u.list_birthday = TRUE
            AND j.listed = TRUE
        ) AS birthdays
        WHERE next_birthday < (:today + INTERVAL #{distance} DAY)
        ORDER BY next_birthday ASC
      ), { :today => Time.zone.today, :now => Time.zone.now } ]

      count = 0
      users.inject(Hash.new) do |memo, user|
        birthday = user.next_birthday
        memo[birthday] = [] unless memo[birthday]
        memo[birthday] << user
        memo
      end.select do |key, users|
        if count < max
          count += users.count
          true
        else
          false
        end
      end
    end
  end

  def next_birthday
    return nil if birthday.nil?
    this_year = Date.new(Time.zone.today.year, birthday.month, birthday.day)
    this_year < Time.zone.today ? this_year + 1.year : this_year
  end

  def age
    return nil if birthday.nil?
    Time.zone.now.year - birthday.year 
  end

  def age_on_next_birthday
    return nil if birthday.nil?
    next_birthday.year - birthday.year
  end

private
  # called after validation
  def put_together_birthday
    self.birthday = if Date.valid_civil?(birthday_year.to_i, birthday_month.to_i, birthday_day.to_i)
      Date.new(birthday_year.to_i, birthday_month.to_i, birthday_day.to_i) 
    end
  end

  # called after creation
  def make_directories
    FileUtils.mkdir_p(prefabs_dir)
  end

  # called after creation
  def save_invitation_code
    self.invitation_code.save!
  end
  
  # called after destruction
  def remove_root_directory
    FileUtils.rm_r(userspace_dir)
  end
  
  # validation method
  def birthday_must_be_valid_datestamp
    return if birthday_day.blank? and birthday_month.blank? and birthday_year.blank?
    date_segments = [:birthday_day, :birthday_month, :birthday_year]
    error = false

    date_segments.each do |segment|
      value = send(segment)
      error = true and break if value.blank? or !value.to_s.match(/^\d+$/)
    end

    errors.add(:birthday, :not_a_date) if error or Date.valid_civil?(birthday_year.to_i, birthday_month.to_i, birthday_day.to_i).nil?
  end
  # validation method
  def invitation_code_should_exist
    if @invitation_code_name && !InvitationCode.exists?(:name => @invitation_code_name)
      self.errors.add(:invitation_code_name, :invitation_code_isnt_real)
    end
  end

  # validation method
  def invitation_code_should_be_unused
    if @invitation_code_name && InvitationCode.exists?(:name => @invitation_code_name)
      invite_code = InvitationCode.find_by_name(@invitation_code_name)
      unless invite_code.user_id.nil? or invite_code.user_id == self.id
        self.errors.add(:invitation_code_name, :invitation_code_already_used)
      end
    end
  end
  
  # validation method
  def given_email_should_match_address_invitation_code_was_sent_to
    if self.invitation_code && self.email != self.invitation_code.email_address
      self.errors.add(:email, :invitation_code_email_mismatch)
    end
  end

  # validation method
  def username_must_contain_at_least_three_alphanumerics
    if !self.username.blank? and self.username.tr('^A-Za-z0-9', '').length < 3
      self.errors.add(:username, :username_min_alnum)
    end
  end

  def raw_errors
    errors.instance_variable_get("@errors")
  end
end
