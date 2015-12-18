class Hash
  # Original source: http://www.ruby-forum.com/topic/142809
  # Copied at: http://snippets.dzone.com/posts/show/4706
  #---
  # NOTE: This is in Rails 2.3 now, should we replace implementation here with that? (it's basically same)
  def deep_merge(second)
    # Since Configuration objects have a Hash member named vars, allow Hash.deep_merge(Configuration)
    if defined?(Configuration)
      if second.is_a? Configuration and !second.vars.nil?
        second = second.vars
      end
    end

    merger = proc do |k,v1,v2|
      if v1.is_a?(Hash) && v2.is_a?(Hash)
        v1.merge(v2, &merger)
      else
        v2
      end
    end
    self.merge(second, &merger)
  end
  
  def deep_merge!(second)
    replace(deep_merge(second))
  end
end
