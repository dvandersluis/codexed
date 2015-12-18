module AprilFoolsHelper
  def jumble(text)
    text.split(" ").map do |word|
      word.chars.to_a.shuffle.join
    end.join(" ") unless text.blank?
  end
end
