class RenameFavoriteJournalsToUserFavorites < ActiveRecord::Migration
  def self.up
    rename_table :favorite_journals, :user_favorites
  end

  def self.down
    rename_table :user_favorites, :favorite_journals
  end
end
