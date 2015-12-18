class Hash
  # Removes keys found in other from the hash. If a key 
  def subtract_keys(other = {})
    hash = self.class.new.update(self)
    other.each do |key, val|
      next if !hash.keys.include?(key)

      if other[key].is_a? Hash and hash[key].is_a? Hash
        hash[key] = hash[key].subtract_keys(other[key])
      else
        hash.delete key
      end
    end
   
    hash
  end

  def subtract_keys!(other = {})
    self.replace subtract_keys(other)
  end
end
