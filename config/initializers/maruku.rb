class String
  # Runs a string through Maruku (an implementation/variant of Markdown)
  def marukufy
    Maruku.new(self).to_html
  end
end