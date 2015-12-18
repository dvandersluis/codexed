class Array
  def sort_by!(&block)
    replace(sort_by(&block))
  end
end