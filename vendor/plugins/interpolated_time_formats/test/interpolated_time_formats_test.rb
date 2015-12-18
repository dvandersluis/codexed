require File.dirname(__FILE__) + '/test_helper'

class InterpolatedTimeFormatsTest < Test::Unit::TestCase
  def test_no_interpolation
    assert_equal '05:30', Time.parse('5:30').strftime('%H:%M')
  end
  
  def test_interpolation_for_time
    assert_equal '5:30', Time.parse('5:30').strftime('#{hour}:#{min}')
  end
  
  def test_interpolation_for_date
    assert_equal '12-31-2006', Date.parse('12/31/2006').strftime('#{month}-#{day}-#{year}')
  end
  
  def test_date_strftime_no_format
    assert_equal '2006-12-31', Date.parse('12/31/2006').strftime
  end
  
  def test_time_strftime_no_format
    assert_raise(ArgumentError) {Time.parse('5:30').strftime}
  end
end
