atom_feed do |f|
  
  f.title("#{@user.username}'s Favorite Journals")
  f.updated(@last_updated_time)
  
  for post in @posts
    f.entry(post, :url => post.url, :updated => post.created_at) do |e|
      e.title(post.title)
      if post.protected? && !@correct_key_given
        e.content(%|<p><i>This post is locked. If you know the password, you can #{link_to "visit the journal", journal_post_url(post)} to unlock and read the post.</i></p>|, :type => 'html')
      else
        e.content(post.render_without_template, :type => 'html')
      end
      # not sure if this will suffice or if we need to include the username in the content area
      e.author do |author|
        author.name(post.user.username)
      end
    end
  end
  
end
