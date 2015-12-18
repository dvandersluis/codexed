#require 'benchmark'
#include Benchmark

require 'rubygems'
require 'ruby-prof'

$:.unshift File.dirname(__FILE__)+'/../../../lib'

RAILS_ENV = 'test'

require 'papyrus/_support'
require 'papyrus'

PROFILE = 1

content = %q|Lorem ipsum dolor [sit] amet, consectetuer adipiscing elit. Morbi commodo, ipsum sed pharetra gravida, orci magna rhoncus neque, \\ id pulvinar odio lorem non turpis. Nullam sit amet enim. Suspendisse id velit vitae ligula volutpat condimentum. Aliquam erat [halle]. Sed quis velit. Nulla facilisi. Nulla libero. Vivamus pharetra posuere sapien. Nam consectetuer. Sed aliquam, nunc eget euismod ullamcorper, lectus nunc ullamcorper orci, ["steve" / bibendum] enim nibh eget ipsum. Donec porttitor ligula eu dolor. Maecenas vitae nulla consequat libero cursus ['venenatis'/]. Nam magna enim, accumsan eu, blandit sed, blandit a, eros.

Quisque [facilisis "er'at" "a dui"]. Nam malesuada ornare dolor. Cras gravida, diam sit amet rhoncus ornare, erat elit consectetuer erat, id egestas pede nibh eget "odio". Proin tincidunt, velit vel porta elementum, magna diam molestie [steve], non aliquet massa pede eu diam. Aliquam iaculis. Fusce et ipsum et nulla tristique facilisis. Donec eget sem sit amet lig|

parser = Papyrus::Parser.new
parser.reset!(content)

if PROFILE > 0
  RubyProf.start
end

5000.times { parser.send(:tokenize) }

result = output = nil
if PROFILE > 0
  result = RubyProf.stop
  printer = RubyProf::FlatPrinter.new(result)
  output = StringIO.new
  printer.print(output, :min_percent => 1, :print_file => false)
  puts output.string
end
if PROFILE > 1
  printer = RubyProf::GraphHtmlPrinter.new(result)
  path = "profile-#{Time.now.to_i}.html"
  File.open(path, 'w') do |file|
    printer.print(file, :min_percent => 1, :print_file => true)
  end
  puts "Call graph written to #{path}."
end