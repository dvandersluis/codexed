class Hash
  def -(other_hash)
    self.dup.delete_if { |k, v| other_hash[k] == v }
  end
end