class ArchiveLayoutType < ActiveRecord::Base
  def name
    t(self.id)
  end
end
