class Array
  # We could have just done Hash[*self.flatten] but that doesn't work recursively.
  # See: <http://judofyr.net/posts/a-better-to-hash.html>
  def to_hash
    self.inject({}) {|memo, element| memo[element[0]] = element[1]; memo }
  end
end