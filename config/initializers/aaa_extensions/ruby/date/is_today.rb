class Date
  # Checks if a date is today, independent of the year
  def is_today?
    return false if self.nil?
    today = Time.respond_to?(:zone) ? Time.zone.today : Date.today
    Date.new(today.year, self.month, self.day) == today
  end
end
