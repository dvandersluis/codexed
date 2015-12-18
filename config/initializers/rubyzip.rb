require 'zip/zipfilesystem'

class Zip::ZipFileSystem::ZipFsDir
  # Copied from FileUtils.mkdir_p
  def mkdir_p(path)
    # optimize for the most common case
    begin
      mkdir(path)
      return
    rescue SystemCallError
      return if @file.directory?(path)
    end

    stack = []
    until path == stack.last   # dirname("/")=="/", dirname("C:/")=="C:/"
      stack << path
      path = @file.dirname(path)
    end
    stack.reverse_each do |path|
      begin
        mkdir(path)
      rescue SystemCallError => err
        raise unless @file.directory?(path)
      end
    end
  end
  
  def full_entries(path)
    entries(path).reject {|x| x.starts_with?(".") }.map {|x| path / x }
  end
end