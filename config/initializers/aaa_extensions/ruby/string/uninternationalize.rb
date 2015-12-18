require 'unidecode'

class String
  def uninternationalize
    Unidecoder.decode(self).gsub("[?]", "").gsub(/`/, "'").strip
  end

  def uninternationalize! 
    self.replace uninternationalize
  end
end
