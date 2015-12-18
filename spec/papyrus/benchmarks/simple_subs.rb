#
# Two ways to run:
#
# time ruby simple_subs.rb
# file="profile-$(date +'%Y%m%d%H%M%S').html"; ruby -S ruby-prof -p graph_html simple_subs.rb > $file; open $file
#

require 'setup'

class Array
  def shuffle
    sort_by { rand }
  end
end

class String
  def shuffle
    split(//).shuffle.join
  end
end

class SomeCommands < Papyrus::CustomCommandSet
  define_command :foo do |args|
    "klsfjks fsaklfj sadlkjf"
  end
  
  define_command :bar do |args|
    one, two, three = args
    shuffle(one, two, three).join(" ")
  end
  
  def shuffle(*words)
    words.shuffle.map {|word| word.shuffle }
  end
end

#----------------------

content = <<EOT
Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Morbi commodo, ipsum sed pharetra gravida, orci magna rhoncus neque, id pulvinar odio lorem non turpis. Nullam sit amet enim. Suspendisse id velit vitae ligula volutpat condimentum. Aliquam erat [halle]. Sed quis velit. Nulla facilisi. Nulla libero. Vivamus pharetra posuere sapien. Nam consectetuer. Sed aliquam, nunc eget euismod ullamcorper, lectus nunc ullamcorper orci, [steve] bibendum enim nibh eget ipsum. Donec porttitor ligula eu dolor. Maecenas vitae nulla consequat libero cursus venenatis. Nam magna enim, accumsan eu, blandit sed, blandit a, eros.

Quisque facilisis erat a dui. Nam malesuada ornare dolor. Cras gravida, diam sit amet rhoncus ornare, erat elit consectetuer erat, id egestas pede nibh eget odio. Proin tincidunt, velit vel porta elementum, magna diam molestie [steve], non aliquet massa pede eu diam. Aliquam iaculis. Fusce et ipsum et nulla tristique facilisis. Donec eget sem sit amet ligula viverra gravida. Etiam vehicula urna velQuisque. Suspendisse sagittis ante a urna. Morbi a est quis orci consequat rutrum. Nullam [foo] feugiat felis. Integer adipiscing semper ligula. Nunc molestie, nisl sit amet cursus convallis, sapien lectus pretium metus, vitae pretium enim wisi id lectus. [bar spoonerism calibration sequential] vestibulum. Etiam vel nibh. Nulla facilisi. Mauris pharetra. Donec augue. Fusce ultrices, neque id dignissim ultrices, tellus mauris dictum elit, vel lacinia enim metus eu nunc.

Proin at eros non eros adipiscing mollis. Donec semper turpis sed diam. Sed consequat ligula nec tortor. Integer eget sem. Ut vitae enim eu [michael] vehicula gravida. Morbi ipsum ipsum, porta nec, tempor id, auctor vitae, purus. Pellentesque neque. Nulla luctus erat vitae libero. Integer nec enim. Phasellus aliquam enim et tortor.
EOT

parser = Papyrus::Parser.new(
  :custom_commands => SomeCommands.new,
  :vars => { 'michael' => 'jackson', 'halle' => 'berry', 'steve' => 'spurrier' }
)

500.times do
  doc = parser.parse(content)
  doc.output
end