class String
  def self.random(length=20)
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ("0".."9").to_a
    hash = ""; length.times { hash << chars[rand(chars.size)] }; hash
  end
end