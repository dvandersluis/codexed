class Pathname
  def /(other)
    File.join(self.to_s, other.to_s)
  end
end