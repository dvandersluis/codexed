require 'pp'
class Object
  # like pretty_print_inspect, but uses PP.pp instead of PP.singleline_pp
  def pretty_inspect
    PP.pp(self, '')
  end
end