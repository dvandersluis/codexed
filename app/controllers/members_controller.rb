class MembersController < BaseController
  def index
    @search_langs = Language.popular
    @page = params[:page] || 1

    @search = params[:search] || 'all'
    @search = 'all' if @search !~ /^[a-z0-9]$/i
    
    @lang = (params[:lang].is_a?(Array) ? params[:lang].first : params[:lang]) || 'all'
    @lang = 'all' unless @lang == '0' or !Language.find_by_id(@lang).nil?
    
    @sort = ((params[:sort].is_a?(Array) ? params[:sort].first : params[:sort]) || 'username').downcase
    @sort = 'username' unless %W(username journal_title member_since last_updated language).include? @sort
    
    @dir = ((params[:dir].is_a?(Array) ? params[:dir].first : params[:dir]) || 'asc').downcase
    @dir = 'asc' unless %W(asc desc).include? @dir
  
    # Dynamically build the WHERE clause
    where = [["journals.privacy != 'C'"]]
    where << ["users.username LIKE ?", "#{@search}%"] if @search != 'all'
    where << ["(language_id IS NULL OR language_id NOT IN (?))", @search_langs.collect(&:id)] if @lang == '0'
    where << ["language_id = ?", @lang] if @lang != 'all' and @lang.to_i > 0
    @where_clause = [ where.collect(&:first).join(" AND "), *where.collect{|i| i[1]}.select{|i| !i.nil?} ]

    # Set up sorting by column
    @joins = "LEFT JOIN posts ON posts.id = journals.current_entry_id" if @sort == 'last_updated'
    @order = case @sort
      when 'username'       then "users.username"
      when 'journal_title'  then "title"
      when 'member_since'   then "users.created_at"
      when 'last_updated'   then "posts.created_at"
    end
      
    @journals = Journal.paginate_by_listed true,
      :page => @page, :per_page => 25,
      :conditions => @where_clause, 
      :joins => @joins,
      :order => ("#{@order} #{@dir.upcase}" if !@order.nil?)

    redirect_to "/members/#{@search}" if @journals.total_entries > 0 && @journals.out_of_bounds?

    @url_params = @lang != 'all' ? { :lang => @lang } : {}
    @url_params.merge!({ :sort => params[:sort] }) if params[:sort]
    @url_params.merge!({ :dir => params[:dir] }) if params[:dir]

    if @sort == "language"
      @journals.sort_by! do |journal|
        # Hackish method to move Unspecified / Other to the end
        (Language.strings[journal.language_id].uninternationalize unless journal.language_id.nil?) || "zzzz"
      end
      @journals.reverse! if @dir.downcase == 'desc'
    end
  end

  def birthdays
    now = Time.zone.now
    day, month, year = now.day, now.month, now.year
    months = (month+1..12).to_a + (1..month-1).to_a

    @birthdays = []
    @birthdays << User.birthdays_in(month, day, day) # Get today's birthdays
    @birthdays << User.birthdays_in(month, day + 1)
    months.each do |m|
      @birthdays << User.birthdays_in(m)
    end
    @birthdays << User.birthdays_in(month, 1, day - 1)

    @headings = []
    ([month] + months + [month]).each do |m|
      year += 1 if m == 1 and !@headings.empty?
      @headings << [year, m]
    end
  end
end
