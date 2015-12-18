class Admin::CategoriesController < Admin::BaseController
  before_filter :set_user_and_journal
  before_filter :collect_categories

  def index
  end

  def add_category
    respond_to do |format|
      format.html { redirect_to :action => :new }
      format.js do
        @category = flash[:category] || @journal.categories.build
        render :layout => false
      end
    end
  end

  def new
    @category = flash[:category] || @journal.categories.build
    @privacy_allowed = true
    render :action => 'form'
  end

  def edit
    @category = flash[:category] || find_category(:missing_record_to_edit) or return
    @privacy_allowed = @category.parent.nil? || @category.parent.privacy != "C"
    render :action => 'form'
  end

  def create
    @category = @journal.categories.build(params[:category])
    cancel(:new_category_canceled) and return if params[:cancel]

    respond_to do |format| 
      format.html { perform_save(:create, params) }
      format.js do
        render :update do |page|
          if @category.save
            @post = Post.new
            @post.category_ids = params[:category_ids].split(",").map(&:to_i)
            page << "facebox.close()"
            
            page.replace_html('category_list', categories_select(:post, :category_ids, @journal.categories(true).roots.sort_by(&:name)))
          else
            flash[:category] = @category
            page << "facebox.loading()" 
            page << "facebox.loadUrl('/admin/categories/add_category')" 
          end
        end
      end
    end
  end

  def update
    @category = find_category(:missing_record_to_update) or return
    @category.attributes = params[:category] 
    cancel(:changes_to_category_not_saved) and return if params[:cancel]
    perform_save(:update, params)
  end
  
  def delete
    @category = find_category(:missing_record_to_delete) or return
  end

  def destroy
    @category = find_category(:missing_record_to_delete) or return
    name = h(@category.name)
    descendant_count = @category.descendants.size
    
    @category.destroy
    
    if descendant_count == 0
      message = t(:category_destroyed, :name => name)
    else
      message = t(:category_and_subcats_destroyed, :name => name, :count => descendant_count)
    end

    flash[:success] = message.strip
    redirect_to :action => 'index'
  end

private
  def collect_categories
    @categories = @journal.sorted_categories
  end

  def cancel(message)
    flash[:notice] = t(message, :name => h(@category.name))
    redirect_to :action => 'index'
  end
  
  def perform_save(action, params)
    @category.generate_slug if @category.autoupdate_slug?

    if @category.save
      # Tried to save a subcategory of a private category as public
      if !params[:category][:privacy].nil? and params[:category][:privacy] != @category.privacy
        flash[:notice] = t(:privacy_changed) 
      end

      # Saved a category with subcategories as private
      if @category.descendants.size > 0 and params[:category][:privacy] == "C"
        flash[:notice] = t(:privacy_changed_subcategories, :name => h(@category.name))
      end

      flash[:success] = t((action == :create ? :category_created : :category_updated), :name => h(@category.name))
      redirect_to :action => 'index'
    else
      flash[:category] = @category

      if action == :create
        redirect_params = {:action => :new}
      elsif action == :update
        @category[:parent_id] = params[:category][:parent_id] # Because parent_id is attr_protected, needed to autopopulate
        redirect_params = {:action => :edit, :id => @category.id}
      end

      redirect_to redirect_params
    end
  end
  
  def find_category(*args)
    error_key = args.pop
    other_category = args.first
    category = other_category || @journal.categories.find_by_id(params[:id])
    if category.nil?
      flash[:error] = error_key.is_a?(Symbol) ? t(error_key, :record => t('models.category', :count => 1).downcase, :scope => 'general.messages') : error_key
      redirect_to :action => 'index'
      return false
    end
    category
  end
end
