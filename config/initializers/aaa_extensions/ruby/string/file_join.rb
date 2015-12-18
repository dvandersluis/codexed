class String
  # Easy File.join
  def /(str)
    File.join(self, str.to_s)
  end
end