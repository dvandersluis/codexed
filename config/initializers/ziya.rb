# Initializes the ZiYa Framework
Ziya.initialize( 
  #:logger      => "#{Rails.root}/log/ziya.log",
  :helpers_dir => "#{Rails.root}/app/helpers/ziya",
  :themes_dir  => "#{Rails.root}/public/charts/themes"
)
