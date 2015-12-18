class Hash
  def only(*keys)
    keys.inject({}) {|h,k| h[k] = self[k] if include?(k); h }
  end
end