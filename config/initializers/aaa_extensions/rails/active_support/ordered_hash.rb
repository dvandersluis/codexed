class ActiveSupport::OrderedHash
  def sort_by(&block)
    self.class.new(super(&block))
  end
  
  # Alternate initialization.
  # Backported from Rails 2.4/3.0, see
  # <http://github.com/rails/rails/commit/e1854e0b199fba352ddcaa58a3af168e8cc70e3a>
  def self.[](*args)
    ordered_hash = new
    args.each_with_index { |val,ind|
      # Only every second value is a key.
      next if ind % 2 != 0
      ordered_hash[val] = args[ind + 1]
    }
    ordered_hash
  end
end