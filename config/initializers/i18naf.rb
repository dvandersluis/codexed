class AprilFoolsI18n < CodexedI18n
  def translate(locale, key, options = {})
    if (string = super(locale, key, options)).is_a? String
      string = string.split(" ").map do |word|
        word.chars.to_a.shuffle.join
      end.join(" ")
    end

    string
  end
end

I18n.backend = AprilFoolsI18n.new if Codexed.april_fools?(2011)
