class AddTagArchiveToArchiveLayoutTypes < ActiveRecord::Migration
  def self.up
    type = ArchiveLayoutType.new(:name => 'Tag archive page')
    type.id = 'tag_archive'
    type.save!
    puts "Added archive layout type 'tag_archive'."
  end

  def self.down
    ArchiveLayoutType.find('tag_archive').destroy
  end
end
