class Hash
  # in Ruby 1.8 this returns an array, patch this so it returns a hash.
  # it's slower but it's less surprising
  def select(&block)
    inject({}) {|h,(k,v)| h[k] = v if yield(k,v); h }
  end
end