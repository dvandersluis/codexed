class Array
  # Assuming that each element in the array is a hash, creates a new hash by
  # deleting the key from each hash, using its value as the new key, and using the rest of
  # the hash as the value.
  #
  # So an array that looks like this:
  #
  #  [
  #    { :foo => 'bar', :baz => 'quux' },
  #    { :foo => 'zoo', :baz => 'zap' }
  #  ]
  #
  # Would turn into this:
  #
  #  {
  #    'bar' => { :baz => 'quux' },
  #    'zoo' => { :baz => 'zap' }
  #  }
  def to_ordered_hash_by(key)
    inject(ActiveSupport::OrderedHash.new) {|new_hash, hash| new_hash[hash.delete(key)] = hash; hash }
  end
end