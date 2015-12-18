=begin
if defined?(RubyProf)
  
  class RubyProf::GraphHtmlPrinter

    PERCENTAGE_WIDTH = 8  unless defined?(PERCENTAGE_WIDTH)
    TIME_WIDTH       = 10 unless defined?(TIME_WIDTH)
    CALL_WIDTH       = 20 unless defined?(CALL_WIDTH)

    # Make the row wider that lists the called method
    def template
'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<style media="all" type="text/css">
  table {
    border-collapse: collapse;
    border: 1px solid #CCC;
    font-family: Verdana, Arial, Helvetica, sans-serif;
    font-size: 9pt;
    line-height: normal;
  }

  th {
    text-align: center;
    border-top: 1px solid #FB7A31;
    border-bottom: 1px solid #FB7A31;
    background: #FFC;
    padding: 0.3em;
    border-left: 1px solid silver;
  }

  tr.break td {
    border: 0;
    border-top: 1px solid #FB7A31;
    padding: 0;
    margin: 0;
  }

  tr.method td {
    font-weight: bold;
  }

  td {
    padding: 0.3em;
  }

  td:first-child {
    width: 190px;
    }

  td {
    border-left: 1px solid #CCC;
    text-align: center;
  } 

  .method_name {
    text-align: left;
    max-width: 55em;
  }
</style>
</head>
<body>
  <h1>Profile Report</h1>
  <!-- Threads Table -->
  <table>
    <tr>
      <th>Thread ID</th>
      <th>Total Time</th>
    </tr>
    <% for thread_id, methods in @result.threads %>
    <tr>
      <td><a href="#<%= thread_id %>"><%= thread_id %></a></td>
      <td><%= thread_time(thread_id) %></td>
    </tr>
    <% end %>
  </table>

  <!-- Methods Tables -->
  <% for thread_id, methods in @result.threads
       total_time = thread_time(thread_id) %>
    <h2><a name="<%= thread_id %>">Thread <%= thread_id %></a></h2>

    <table>
      <tr>
        <th><%= sprintf("%#{PERCENTAGE_WIDTH}s", "%Total") %></th>
        <th><%= sprintf("%#{PERCENTAGE_WIDTH}s", "%Self") %></th>
        <th><%= sprintf("%#{TIME_WIDTH}s", "Total") %></th>
        <th><%= sprintf("%#{TIME_WIDTH}s", "Self") %></th>
        <th><%= sprintf("%#{TIME_WIDTH}s", "Wait") %></th>
        <th><%= sprintf("%#{TIME_WIDTH+2}s", "Child") %></th>
        <th><%= sprintf("%#{CALL_WIDTH}s", "Calls") %></th>
        <th class="method_name">Name</th>
        <th>Line</th>
      </tr>

      <% min_time = @options[:min_time] || (@options[:nonzero] ? 0.005 : nil)
         methods.sort.reverse_each do |method|
          total_percentage = (method.total_time/total_time) * 100
          next if total_percentage < min_percent
          next if min_time && method.total_time < min_time
          self_percentage = (method.self_time/total_time) * 100 %>

          <!-- Parents -->
          <% for caller in method.parents %>
          <%   next if min_time && caller.total_time < min_time  %>
            <tr>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td><%= sprintf("%#{TIME_WIDTH}.2f", caller.total_time) %></td>
              <td><%= sprintf("%#{TIME_WIDTH}.2f", caller.self_time) %></td>
              <td><%= sprintf("%#{TIME_WIDTH}.2f", caller.wait_time) %></td>
              <td><%= sprintf("%#{TIME_WIDTH}.2f", caller.children_time) %></td>
              <% called = "#{caller.called}/#{method.called}" %>
              <td><%= sprintf("%#{CALL_WIDTH}s", called) %></td>
              <td class="method_name"><%= create_link(thread_id, caller.target) %></td>
              <td><a href="file://<%=h srcfile=File.expand_path(caller.target.source_file) %>#line=<%= linenum=caller.line %>" title="<%=h srcfile %>:<%= linenum %>"><%= caller.line %></a></td>
            </tr>
          <% end %>

          <tr class="method">
            <td><%= sprintf("%#{PERCENTAGE_WIDTH-1}.2f\%", total_percentage) %></td>
            <td><%= sprintf("%#{PERCENTAGE_WIDTH-1}.2f\%", self_percentage) %></td>
            <td><%= sprintf("%#{TIME_WIDTH}.2f", method.total_time) %></td>
            <td><%= sprintf("%#{TIME_WIDTH}.2f", method.self_time) %></td>
            <td><%= sprintf("%#{TIME_WIDTH}.2f", method.wait_time) %></td>
            <td><%= sprintf("%#{TIME_WIDTH}.2f", method.children_time) %></td>
            <td><%= sprintf("%#{CALL_WIDTH}i", method.called) %></td>
            <td class="method_name"><a name="<%= method_href(thread_id, method) %>"><%= h method.full_name %></a></td>
            <td><a href="file://<%=h srcfile=File.expand_path(method.source_file) %>#line=<%= linenum=method.line %>" title="<%=h srcfile %>:<%= linenum %>"><%= method.line %></a></td>
          </tr>

          <!-- Children -->
          <% for callee in method.children %>
          <%   next if min_time && callee.total_time < min_time  %>
            <tr>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td><%= sprintf("%#{TIME_WIDTH}.2f", callee.total_time) %></td>
              <td><%= sprintf("%#{TIME_WIDTH}.2f", callee.self_time) %></td>
              <td><%= sprintf("%#{TIME_WIDTH}.2f", callee.wait_time) %></td>
              <td><%= sprintf("%#{TIME_WIDTH}.2f", callee.children_time) %></td>
              <% called = "#{callee.called}/#{callee.target.called}" %>
              <td><%= sprintf("%#{CALL_WIDTH}s", called) %></td>
              <td class="method_name"><%= create_link(thread_id, callee.target) %></td>
              <td><a href="file://<%=h srcfile=File.expand_path(method.source_file) %>#line=<%= linenum=callee.line %>" title="<%=h srcfile %>:<%= linenum %>"><%= callee.line %></a></td>
            </tr>
          <% end %>
          <!-- Create divider row -->
          <tr class="break"><td colspan="9"></td></tr>
      <% end %>
    </table>
  <% end %>
</body>
</html>'
    end
  end
  
end
=end