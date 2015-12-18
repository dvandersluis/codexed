libdir = File.join(File.dirname(__FILE__), 'lib/mcmire/title_helpers/')
%w(controller helper).each {|file| require libdir + file }

ActionView::Base.class_eval { include Mcmire::TitleHelpers::Helper }
ActionController::Base.class_eval { include Mcmire::TitleHelpers::Controller }