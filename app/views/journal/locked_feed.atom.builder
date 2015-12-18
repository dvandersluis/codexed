atom_feed(:root_url => journal_url(@journal.user, :only_path => false), :url => journal_url(@journal.user, :only_path => false)) do |f|
  
  f.title(@journal.title)
  f.updated(@last_updated_time)
  
  f.entry(nil, :url => journal_url(@journal.user, :only_path => false)) do |e|
    e.title("Locked Journal")
    e.content(%|<p><i>This journal is locked. If you know the password, you can #{link_to "visit the journal", journal_url(@journal.user, :only_path => false)} to unlock it.</i></p>|, :type => 'html')

    # not sure if this will suffice or if we need to include the username in the content area
    e.author do |author|
      author.name(@user.username)
    end
  end
  
end
