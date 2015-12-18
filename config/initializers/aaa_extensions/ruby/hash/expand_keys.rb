class Hash
  def expand_keys(newhash = {})
    self.each do |k, v|
      k = k.to_s
      parts = k.split('.')

      hash_pointer = newhash

      parts[0...-1].each do |k2|
        hash_pointer[k2] = {} if hash_pointer[k2].nil?
        hash_pointer = hash_pointer[k2]
      end

      hash_pointer[parts[-1]] = v
    end
    newhash
  end
end
