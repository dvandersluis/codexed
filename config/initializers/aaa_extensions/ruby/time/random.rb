class Time
  def self.random
    local(Time.now.year, rand(11)+1, rand(28)+1, rand(23), rand(59), rand(59))
  end
end