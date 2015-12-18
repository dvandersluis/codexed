class Admin::ArchiveLayoutsController < Admin::BaseController
  before_filter :set_user_and_journal
  before_filter :setup_form, :only => [:new, :create, :edit, :update]
  before_filter :handle_cancel, :only => [:create, :update]
  before_filter :build_archive_layout, :only => [:new, :create]
  before_filter :load_archive_layout, :only => [:edit, :update, :delete, :destroy]
  
  def index
    @archive_layouts = @journal.archive_layouts.inject({}) {|h,l| h[l.type_id] = l; h }
    @archive_layout_types = %w(complete_archive category_archive tag_archive).map {|id| ArchiveLayoutType.find(id) }
  end
  
  def new
    # Load the fake entry that corresponds to the archive layout as the initial layout.
    fake_entry_name = @archive_layout.type_id == "complete_archive" ? "archive" : @archive_layout.type_id
    post = @journal.posts.find_fake_by_name(fake_entry_name)
    @archive_layout.title = post.title
    @archive_layout.content = Template.run_through_erb(post.raw_body, 'template' => @template).strip
  end
  
  def create
    if @archive_layout.save
      url = journal_archive_url(@archive_layout_type)
      flash[:success] = t(:archive_layout_created, :layout => @archive_layout_type.name)
      flash[:success] << %| <a href="#{url}">#{t("messages.check_it_out")}</a>| if url
      redirect_to :action => 'index'
    else
      render :action => 'new'
    end
  end
  
  def edit
  end
  
  def update
    if @archive_layout.save
      url = journal_archive_url(@archive_layout_type)
      flash[:success] = t(:archive_layout_updated, :layout => @archive_layout_type.name)
      flash[:success] << %| <a href="#{url}">#{t("messages.check_it_out")}</a>| if url
      redirect_to :action => 'index'
    else
      render :action => 'edit'
    end
  end
  
  def delete
  end
  
  def destroy
    @archive_layout.destroy
    flash[:success] = t(:archive_layout_destroyed, :layout => @archive_layout_type.name)
    redirect_to :action => 'index'
  end
  
private
  # before filter
  def build_archive_layout
    key = params[:id]
    if @archive_layout_type = ArchiveLayoutType.find_by_id(params[:id])
      @archive_layout = @journal.archive_layouts.build
      @archive_layout.attributes = params[:archive_layout]
      @archive_layout.type = @archive_layout_type
    else
      flash[:error] = t(:invalid_layout_given)
      redirect_to :action => 'index'
    end
  end
  
  # before filter
  def setup_form
    @selectable_templates = [[t("form.use_default_template"), '']] + @journal.templates.find(:all, :order => 'name').map {|t| [t.name, t.id] }
  end

  # before filter
  def load_archive_layout
    if @archive_layout = @journal.archive_layouts.find_by_type_id(params[:id])
      @archive_layout.attributes = params[:archive_layout]
      @archive_layout_type = @archive_layout.type
    else
      flash[:error] = t(:invalid_layout_given)
      redirect_to :action => 'index'
    end
  end
  
  # before filter
  def handle_cancel
    redirect_to :action => 'index' if params[:cancel]
  end
end
