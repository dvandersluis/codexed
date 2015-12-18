class HashWithIndifferentAccess < Hash
  # add support for the block to update
  def update(other_hash, &blk)
    other_hash.each_pair do |key, value|
      if block_given?
        value = blk.call(key, self[key], value) 
      end
      self[key] = value
    end
    self
  end
end