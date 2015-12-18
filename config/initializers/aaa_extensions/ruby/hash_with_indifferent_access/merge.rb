class HashWithIndifferentAccess < Hash
  # add support for the block to merge
  def merge(hash, &blk)
    self.dup.update(hash, &blk)
  end
end