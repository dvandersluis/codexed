module Haml::Filters::Style
  include Haml::Filters::Base
  lazy_require 'sass/engine'

  def render(text)
    <<END
<style type='text/css'>
<!--
  #{::Sass::Engine.new(text).render}
-->
</style>
END
  end
end