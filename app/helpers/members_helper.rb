module MembersHelper
  def flip_direction(dir)
    dir.downcase == 'asc' ? 'desc' : 'asc'
  end
end
