module DeleteOrphanedFiles
private
  # Should be called before the record is saved
  def delete_orphaned_files
    return if self.before_last_saved.nil?
    prev_filepath = self.before_last_saved.filepath
    return if self.filepath == prev_filepath or !File.exists?(prev_filepath)
    File.delete(prev_filepath)
    logger.info "Deleted orphaned file: #{prev_filepath}"
  end
end