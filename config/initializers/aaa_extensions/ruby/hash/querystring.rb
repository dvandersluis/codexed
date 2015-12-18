class Hash
  # Create a query string out of a hash
  def make_query_string
    self.inject([]) { |memo, pair| memo.push("#{CGI::escape(pair[0].to_s)}=#{CGI::escape(pair[1].to_s)}") }.join("&")
  end
end
