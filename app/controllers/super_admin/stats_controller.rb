class SuperAdmin::StatsController < SuperAdmin::BaseController
  
  helper Ziya::Helper
  
  def index
  end
  
  #---
  
  def num_records_by_date_graph
    xlabels, data = Graph.num_records_by_date(params[:table])
    chart = Ziya::Charts::Line.new
    chart.add :axis_category_text, xlabels
    chart.add :series, "Users by Date", data
    chart.add :theme, "codexed"
    respond_to do |fmt|
      fmt.xml { render :xml => chart }
    end
  end
  
end
