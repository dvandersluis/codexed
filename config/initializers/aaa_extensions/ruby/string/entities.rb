require "htmlentities"

class String
  def encode_entities
    HTMLEntities.encode_entities self
  end

  def encode_entities!
    self.replace self.encode_entities
  end

  def decode_entities
    HTMLEntities.decode_entities self
  end

  def decode_entities!
    self.replace self.decode_entities
  end
end
