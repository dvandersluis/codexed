class Admin::EntriesController < Admin::PostsController
  # Tell I18n to use PostController's scope.
  @controller_scope = "admin.posts"
end
