module Kernel
  def this_method
    m = /`(.*?)'/.match(caller[0]) and m[1]
  end
end