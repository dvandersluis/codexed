module Papyrus
  module Commands; end
end

Dir.entries(File.dirname(__FILE__)+'/commands').each do |file|
  next if file =~ /^\./
  filenoext = file.sub(/\.[^.]+$/, "")
  Papyrus::Commands.const_get(filenoext.classify.to_sym)  # load class dynamically
end