class HashWithIndifferentAccess
  def delete(*keys)
    keys.map! {|key| convert_key(key) }
    super(*keys)
  end
end