class HashWithIndifferentAccess < Hash
  # Kind of a mixture between except and diff
  def splice_named(*keys)
    rejected = Set.new(respond_to?(:convert_key) ? keys.map {|k| convert_key(k) } : keys)
    discard, keep = partition {|k,| rejected.include?(k) }.map(&:to_hash)
    self.class.new(discard) 
  end

  def splice_named!(*keys)
    splice = splice_named(*keys)
    replace(self - splice)
    self.class.new(splice)
  end

  alias_method :only, :splice_named
  alias_method :only!, :splice_named!
end
