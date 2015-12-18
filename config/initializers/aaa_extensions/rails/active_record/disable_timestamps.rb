# Extend ActiveRecord::Base to make it easier to temporarily disable timestamps
module ActiveRecord
  class Base
    def self.disabling_timestamps
      record_timestamps = false
      ret = yield
      record_timestamps = true
      ret
    end
  end
end