# Add convenient date/time formats
ActiveSupport::CoreExtensions::Date::Conversions::DATE_FORMATS.merge!(
  :std => '#{month}/#{day}/%Y',
  :nice => '%A, %B #{day}, %Y',
  :squeezed => "%Y%m%d"
)
ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(
  :std => '#{month}/#{day}/%Y #{mil_hr_to_civ_hr(hour)}:%M:%S %p',
  :nice => '%A, %B #{day}, %Y at #{mil_hr_to_civ_hr(hour)}:%M %p',
  :squeezed => "%Y%m%d%H%M%S"
)

def mil_hr_to_civ_hr(hour)
  mod = (hour % 12)
  mod + (12 * (mod > 0 ? 0 : 1))
end