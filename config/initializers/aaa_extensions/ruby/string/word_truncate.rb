class String
  def word_truncate(length, separator=" ")
    return self if self.length <= length
    # trim to length
    # then, if we end up in the middle of a word, chop off the rest of the word
    first(length).sub(/#{separator}\w+$/, "")
  end
end