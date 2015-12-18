class Graph
  class << self

    def num_records_by_date(table)
      xlabels = []
      data = []
      records = ActiveRecord::Base.select_all(%|
        SELECT DATE(created_at) AS created_on, SUM(1) as count
        FROM #{table}
        GROUP BY created_on
      |)
      records_by_date = records.inject({}) {|h,u| h[u.created_on] = u.count; h }
      dates = records.map {|u| u.created_on }
      mindate, maxdate = dates.min, dates.max
      adjmindate, adjmaxdate = mindate.at_beginning_of_month, maxdate.at_end_of_month
      all_dates = (adjmindate .. adjmaxdate).to_a
      sum = 0
      lastdate = nil
      all_dates.each_with_index do |date, i|
        value = nil
        if (mindate .. maxdate).include?(date)
          count = records_by_date[date] || 0
          sum += count
          value = sum
        end
        label = date.strftime("%-d %b#{lastdate && date.year == lastdate.year ? '' : ' %y'}")
        #data << { :value => value, :label => label }
        data << value
        xlabels << (show_label?(all_dates.size, date, i) ? label : "")
        lastdate = date
      end
      [xlabels, data]
    end
  
    def show_label?(num_points, date, i)
      return true if i == 0 || i == num_points-1
      if num_points >= 150
        date.day == 1 || date.day == 15
      else
        date.wday == 0
      end
    end
  end
end