module Admin::BaseHelper
  def options_tabs
    t_scope 'controllers.admin.options.tabs' do
      [
        [ t(:main), %w(index main) ],
        [ t(:account), 'account' ],
        [ t(:journal), 'journal' ],
        [ t(:formatting), 'formatting' ]
      ]
    end
  end
end
