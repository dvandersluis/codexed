# Via https://rails.lighthouseapp.com/projects/8994/tickets/5604-activesupportinflectorordinalize-not-i18n-enabled
module ActiveSupport
  module Inflector
    def ordinalize(number)
      rules = I18n.t 'number.ordinals', :default => ""

      # Assume English for compat
      rules = {
        :'\d{0,}1[123]\Z' => "%dth",
        :'\d{0,}1\Z'  => "%dst",
        :'\d{0,}2\Z'  => "%dnd",
        :'\d{0,}3\Z'  => "%drd",
        :other => "%dth"
      } unless rules.is_a? Hash 
      
      match = rules.find do |rule|
        number.to_s =~ Regexp.new(rule[0].to_s)
      end
      match = match[1] unless match.nil?
      
      match ||= rules[:other]
      
      match % number
    end
  end
end
