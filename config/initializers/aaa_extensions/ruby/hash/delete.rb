class Hash
  alias_method :orig_delete, :delete
  def delete(*keys)
    ret = keys.flatten.map {|k| orig_delete(k) }
    keys.size == 1 ? ret.first : ret
  end
end