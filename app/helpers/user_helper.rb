module UserHelper
  def birthdays
    users = User.find_upcoming_birthdays
    render :partial => "/birthdays", :locals => { :users => users }
  end

  def recently_updated(n = 10)
    journals = Journal.recently_updated n
    render :partial => "/recently_updated", :locals => { :journals => journals }
  end

  def favorite_journals
    favorite_journals = []

    if !current_user.nil?
      mode = :db
      current_user.ordered_user_favorites.each do |fj|
        if fj.journal.nil?
          temp_journal = Journal.new(:user => User.new(:username => fj.display_name))
          temp_journal.id = fj.journal_id
          favorite_journals.push(temp_journal)
        else
          favorite_journals.push(fj.journal)
        end
      end
      controller = "/admin/user"
    else
      mode = :cookie
      if cookies[:favorites].nil? or cookies[:favorites].empty?
        favorite_journals = nil
      else
        journals = []
        favorites = cookies[:favorites].split(',')
        favorites.each do |fj|
          journal = Journal.find_by_id(fj.to_i)

          if journal.nil?
            # If the journal has been deleted, remove it from the favorites cookie
            favorites.delete(fj)
            cookies[:favorites] = { :value => favorites.join(','), :expires => Time.now + 1.year }
          else
            journals.push(journal)
          end
        end

        favorite_journals = Journal.sort_journals_by_created_at(journals)
      end
      controller = "/user"
    end

    # If a cookie favorites list exist, check if there are any favorites in the cookie list that aren't stored in the db: 
    favorites_to_merge = []
    if mode == :db and !(cookies[:favorites].nil? or cookies[:favorites].blank?)
      cookie_favorites = cookies[:favorites].split(',').map{ |f| f.to_i }
      db_favorites = favorite_journals.collect{ |fj| fj.id if !fj.nil? }
      favorites_to_merge = cookie_favorites - db_favorites
    end

    # Remove any deleted journals from the merge list
    favorites_to_merge.reject! { |fj| !Journal.find_by_id(fj.to_i) }

    render :partial => '/favorite_journals',
      :locals => {
        :mode => mode,
        :favorites_to_merge => favorites_to_merge,
        :favorite_journals => favorite_journals,
        :controller => controller
      }
  end
end
