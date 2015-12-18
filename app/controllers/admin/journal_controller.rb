class Admin::JournalController < Admin::BaseController
  before_filter :set_user_and_journal

  def import
    @import = @journal.import
    @hide_global_messages = true
  end
  
  def export 
    @export = @journal.export
    @hide_global_messages = true
  end
end
