module ExtraAssertions
  
  def self.included(klass)
    klass.class_eval do
      unless @extra_assertions_already_included
        alias_method :old_build_message, :build_message
        alias_method :old_assert_template, :assert_template
        include InstanceMethods
        @extra_assertions_already_included = true
      end
    end
  end
  
  module InstanceMethods
    # Override build_message to get rid of the message prefix, as we never use it
    def build_message(msg, template=nil, *args)
      if msg.blank?
        old_build_message(msg, template, *args)
      else
        msg
      end
    end
    
    # counterpart to assert_instance_of
    def assert_kind_of(klass, object, message="")
      _wrap_assertion do
        assert_equal(Class, klass.class, "assert_instance_of takes a Class as its first argument")
        full_message = build_message(message, "<?> expected to be a kind of\n<?> but was\n<?>.\n", object, klass, object.class)
        assert_block(full_message){object.kind_of?(klass)}
      end
    end
    
    #----
    
    def assert_record_new(record)
      assert(record.new_record?, "Expected #{record.class} to be a new record, but it was saved.")
    end
    alias_method :assert_record_not_saved, :assert_record_new
    def assert_record_not_new(record)
      assert(!record.new_record?, "Expected #{record.class} to be saved, but it never was.")
    end
    alias_method :assert_record_saved, :assert_record_not_new
    
    def assert_record_has_attrs(record, hash)
      attrs = record.attributes.inject({}) {|memo, (k, v)| memo[k.to_sym] = v if hash.include?(k.to_sym) }
      #assert hash_in_record_attrs?(hash, attrs),
      #  "Expected #{record.class} to have attributes <#{hash.inspect}> but it had\n<#{attrs.only(*hash.keys).inspect}> instead."
      assert_equal hash, attrs, "Expected #{record.class} to have attributes <#{hash.inspect}> but it had\n<#{attrs.inspect}> instead."
    end
    def assert_record_not_has_attrs(record, hash)
      assert hash_not_in_record_attrs?(hash, record.attributes), 
        "Expected #{record.class} to not have attributes <#{hash.inspect}> but it did."
    end
    
    # Asserts that the record (or the symbol of the instance variable that holds the record)
    # is not nil, valid, in the database, and has the same attributes as the given hash (or record).
    def assert_record_saved_to(record_or_symbol, record_or_hash)
      _wrap_assertion do
        actual = get_record_from_assign(record_or_symbol)
        #puts "Actual: #{actual.inspect}"
        #puts "Record or hash: #{record_or_hash.inspect}"
        assert_not_nil actual
        assert_valid actual
        assert_record_not_new actual
        if record_or_hash.is_a?(Hash)
          assert_record_has_attrs actual, record_or_hash
        else
          assert_records_equal record_or_hash, actual
        end
      end
    end
    alias_method :assert_record_saved_with, :assert_record_saved_to
    alias_method :assert_record_saved_as, :assert_record_saved_to
    alias_method :assert_record_saved_and_has_attrs, :assert_record_saved_to
    alias_method :assert_record_saved_and_equal_to, :assert_record_saved_to
    
    # Asserts that the record is not valid, a new record, and
    # (optionally) does not have the given attributes.
    def assert_record_new_and_not_valid(record_or_symbol, hash=nil)
      _wrap_assertion do
        record = get_record_from_assign(record_or_symbol)
        assert_not_nil record
        assert_not_valid record
        assert_record_new record
        assert_record_not_has_attrs(record, hash) if hash
      end
    end
    
    # Asserts that the record is not valid, in the db, and
    # (optionally) does not have the given attributes.
    def assert_record_not_new_and_not_valid(record_or_symbol, hash=nil)
      _wrap_assertion do
        record = get_record_from_assign(record_or_symbol)
        assert_not_nil record
        assert_not_valid record
        assert_record_not_new record
        assert_record_not_has_attrs(record, hash) if hash
      end
    end
    
    #-----
    
    def assert_blank(object)
      assert_equal "", object
    end
    def assert_not_blank(object)
      assert_not_equal "", object
    end
    
=begin
    def records_equal?(expected, actual)
      #expected.class == actual.class && (
      #  (!expected.new_record? && !actual.new_record?) ? expected.id == actual.id : expected.attributes.except('id') == actual.attributes.except('id')
      #)
      expected.class == actual.class && (
        ((expected.new_record? || actual.new_record?) && expected.attributes.except('id') == actual.attributes.except('id')) || \
        expected.id == actual.id
      )
    end
=end
    # Asserts that the given records are of the same class, are in the same state (new or in db),
    # and have the same attributes (except for id)
    # XXX: This should use hash_in_record_attrs?, or at least it should exclude id only if the
    # records' states are different
    def assert_records_equal(expected, actual, msg=nil)
      _wrap_assertion do
        assert_kind_of ActiveRecord::Base, expected, "Expected is not a record but a #{expected.class}."
        assert_kind_of ActiveRecord::Base, actual, "Actual is not a record but a #{actual.class}."
        assert_equal expected.class, actual.class,
          "Expected actual to be a <#{expected.class}>, but it is a <#{actual.class}."
        assert (!expected.new_record? == !actual.new_record?),
          "Expected actual to #{!actual.new_record? ? "not" : ""} be a new record just like expected, but it#{!expected.new_record? ? "'s not" : " is"}."
        assert_equal expected.attributes.except(:id), actual.attributes.except(:id),
          "Expected\n<#{expected.inspect}>,\nbut got <#{actual.inspect}> instead."
      end
    end
    
    # Two records are "equal" if they are of different classes, or are not in the same state
    # (new or in db) or have different attributes.
    # XXX: This should use hash_in_record_attrs?, or at least it should exclude id only if the
    # records' states are different
    def records_not_equal?(expected, actual)
      expected.class != actual.class || \
      expected.new_record? || actual.new_record? || 
      expected.attributes.except('id') != actual.attributes.except('id')
    end
    # Asserts that the given records are of different classes, or are not in the same state
    # (new or in db) or have different attributes.
    def assert_records_not_equal(expected, actual, msg=nil)
      _wrap_assertion do
        assert_kind_of ActiveRecord::Base, expected, "#{expected.class} is not a record"
        assert_kind_of ActiveRecord::Base, actual, "#{actual.class} is not a record"
        assert records_not_equal?(expected, actual), "Expected actual to not be equal to <#{expected.inspect}>,\nbut it was."
      end
    end
    
=begin
    # Override default assert_same to account for ActiveRecords.
    # If both the expected and actual values are ARs, then they are "the same" if they have the same id.
=begin
    def assert_same(expected, actual, msg=nil)
      if expected.kind_of?(ActiveRecord::Base) && actual.kind_of?(ActiveRecord::Base) && expected.class == actual.class
        msg ||= "Expected #{expected.class.to_s.downcase} to have an id of <#{expected.id}>, but it was <#{actual.id}> instead."
        assert_block(msg) { expected.id == actual.id }
      else
        msg ||= "Expected <#{actual.inspect}> to be the same as <#{expected.inspect}>, but it wasn't."
        assert_block(msg) { actual.equal?(expected) }
      end
    end
    def assert_not_same(expected, actual, msg=nil)
      if expected.kind_of?(ActiveRecord::Base) && actual.kind_of?(ActiveRecord::Base) && expected.class == actual.class
        msg ||= "Expected #{expected.class.to_s.downcase.pluralize} to NOT have an id of <#{actual.id}>, but they did."
        assert_block(msg) { expected.id != actual.id }
      else
        msg ||= "Expected <#{actual.inspect}> to NOT be the same as <#{expected.inspect}>, but it was."
        assert_block(msg) { !actual.equal?(expected) }
      end
    end
=\end
    
    # Two record objects are the "same" if they are of the same class and have the same id
    # (and hence, both are saved).
    def assert_record_same(expected, actual, msg=nil)
      _wrap_assertion do
        assert expected.kind_of?(ActiveRecord::Base), "#{expected.class} is not a record"
        assert actual.kind_of?(ActiveRecord::Base), "#{actual.class} is not a record"
        msg ||= "Expected <##{expected.class} id: #{expected.id}>, got <##{actual.class} id: #{actual.id}> instead."
        assert_block(msg) { expected.class == actual.class && expected.id == actual.id }
      end
    end
    # Two record objects are not the "same" if they are of different classes or if they
    # have different ids.
    def assert_records_not_same(expected, actual, msg=nil)
      _wrap_assertion do
        assert expected.kind_of?(ActiveRecord::Base), "#{expected.class} is not a record"
        assert actual.kind_of?(ActiveRecord::Base), "#{actual.class} is not a record"
        msg ||= "Expected #{actual.class} to not be a #{expected.class}, but it wasn't."
        assert_block(msg) { expected.class != actual.class || expected.id != actual.id }
      end
    end
=end
    
    def assert_records_coll_equal(expected, actual, msg=nil)
      #inspection = lambda {|o| "#<#{o.class}:#{o.id}>" }
      #msg ||= "Expected:\n[#{expected.map(&inspection).join(", ")}], but got:\n#{actual.map(&inspection).join(", ")}"
      msg = build_message(nil, "Expected:\n<?>\nbut got:\n<?>", expected, actual)
      _wrap_assertion do
        assert expected.is_a?(Array), "Expected is not an array"
        assert actual.is_a?(Array), "Actual is not an array"
        actual.zip(expected).each {|(o1, o2)| assert_records_equal o2, o1, msg }
      end
    end
    
    # this counterbalances assert_valid
    def assert_not_valid(record, msg=nil)
      msg ||= "Expected #{record.class.to_s.downcase} to not be valid, but it was."
      assert_block(msg) { !record.valid? }
    end
    
    def assert_blank(obj, msg=nil)
      msg ||= "Expected <#{obj.inspect}> to be blank, but it wasn't."
      assert_block(msg) { obj.blank? }
    end
    def assert_not_blank(obj, msg=nil)
      msg ||= "Expected <#{obj.inspect}> to not be blank, but it was."
      assert_block(msg) { !obj.blank? }
    end
    
    def assert_empty(obj, msg=nil)
      msg ||= "Expected <#{obj.inspect}> to be empty, but it wasn't."
      assert_block(msg) { obj.empty? }
    end
    def assert_not_empty(obj, msg=nil)
      msg ||= "Expected <#{obj.inspect}> to not be empty, but it was."
      assert_block(msg) { !obj.empty? }
    end
    
    # Override assert_template to accept a symbol
    def assert_template(expected, msg=nil)
      expected = expected.to_s
      old_assert_template(expected, msg)
    end
    
    def assert_layout(expected, msg=nil)
      actual = @response.layout.sub(%r!^layouts/!, "")
      msg ||= build_message(nil, "Expected layout to be <?>, but it was <?>.", expected, actual)
      assert_block(msg) { actual && expected == actual }
    end
    def assert_no_layout(msg=nil)
      actual = @response.layout
      msg ||= build_message(nil, "Expected view to be rendered with no layout, but it was rendered with <?>.", actual)
      assert_block(msg) { actual.nil? }
    end
    
    # Asserts that the specified cookie is set.
    # Even if a cookie is set, it doesn't get committed unless the next request
    # (which may never happen). In any case, it will show up in @request.cookies.
    def assert_cookie(cookie_name, msg=nil)
      cookie_name = cookie_name.to_s
      msg ||= "Expected cookie '#{cookie_name}' to be set, but it wasn't."
      assert_block(msg) { !cookies[cookie_name].blank? || !@request.cookies[cookie_name].blank? }
    end
    # Asserts that the specified cookie is not set.
    # cookies.delete actually empties the cookie, it doesn't delete it, so we need a custom assertion
    # (see <http://blog.codefront.net/2006/09/03/some-functional-testing-gotchas-in-ruby-on-rails/>)
    def assert_no_cookie(cookie_name, msg=nil)
      cookie_name = cookie_name.to_s
      msg ||= "Expected cookie '#{cookie_name}' to be undefined, but it wasn't."
      assert_block(msg) { cookies[cookie_name].blank? }
    end
    
    # Asserts that the instance variable by the given name has the given value,
    # and (optionally) is of the given class.
    def assert_assigned(name, expected=nil, klass=nil)
      actual = assigns(name)
      _wrap_assertion do
        assert_instance_of(klass, actual, "Expected @#{name} to be a #{klass}.") if klass
        if expected
          msg = "Expected @#{name} to be <#{expected.inspect}>,\nbut it was <#{actual.inspect}> instead."
          if expected.kind_of?(ActiveRecord::Base) && actual.kind_of?(ActiveRecord::Base)
            assert_records_equal(expected, actual, msg)
          else
            assert_equal(expected, actual, msg)
          end
        else
          assert_not_nil actual
        end
      end
    end
    
    def assert_not_assigned(name)
      assert_nil assigns(name), "Expected @#{name} to be nil, but it wasn't."
    end
    
    # Asserts that the given value was assigned to the given flash variable.
    def assert_flash(name, expected=nil, msg=nil)
      actual = flash[name]
      if expected
        assert_equal(expected, actual, "Expected flash[:#{name}] to be <#{expected.inspect}>, but it was <#{actual.inspect}> instead.")
      else
        assert_not_nil actual, "Expected flash[:#{name}] to not be nil, but it was."
      end
    end
    # Asserts that flash[symbol] is nil.
    def assert_no_flash(name)
      assert_nil flash[name], "Expected flash[:#{name}] to be nil, but it wasn't."
    end
    
    def assert_session(name, expected=nil)
      actual = session[name]
      if expected
        assert_equal(expected, actual, "Expected session[:#{name}] to be <#{expected.inspect}>, but it was <#{actual.inspect} instead.")
      else
        assert_not_nil actual, "Expected session[:#{name}] to not be nil, but it was."
      end
    end
    def assert_no_session(name)
      assert_nil session[name], "Expected session[:#{name}] to be nil, but it wasn't."
    end
    
    # Asserts that the given record has errors on the given attributes.
    def assert_errors_on(record, *attrs)
      #for attr in attrs
      #  attr = attr.to_s
      #  msg = "Expected #{record.class.to_s.downcase} to have errors on #{attr}, but there were none."
      #  assert_block(msg) { !record.errors.on(attr).blank? }
      #end
      attrs.map!(&:to_s)
      errors = record.errors.instance_variable_get("@errors")
      actual_errors_on = errors.keys.map(&:to_s)
      # double diff
      diff_errors_on = (actual_errors_on - attrs) + (attrs - actual_errors_on)
      msg = "Expected #{record.class.to_s.downcase} to have errors on <#{attrs.join(',')}> but there were errors on <#{actual_errors_on.join(",")}> instead."
      assert_empty(diff_errors_on, msg)
    end
    # Asserts that the errors on the given record include the given message.
    def assert_error(record, attr, message)
      assert_errors_on record, attr
      attr = attr.to_s
      regexp = message.is_a?(Regexp) ? message : /#{message}/ 
      messages = record.errors.on(attr) #record.errors.instance_variable_get("@errors")[attr]
      msg = "Expected #{record.class.to_s.downcase}.#{attr} to have a '#{regexp.source}' error, but it didn't."
      assert_block(msg) { !messages.blank? && messages.any? {|m| m =~ regexp } }
    end
    
  private
    def hash_in_record_attrs?(hash, attrs)
      #hash.keys.all? {|k| key_in_record_attrs(k, hash[k], attrs) }
      hash.keys.all? do |k|
        attrs.include?(k) && hash[k] == attrs[k]
      end
    end
    def hash_not_in_record_attrs?(hash, attrs)
      hash.keys.any? {|k| !key_in_record_attrs(k, hash[k], attrs) }
    end
    def key_in_record_attrs(key, value, attrs)
      if value.is_a?(ActiveRecord::Base)
        attrs.include?(value.class.to_s.foreign_key)
      else
        attrs.include?(key.to_s)
      end
    end
    def get_record_from_assign(record_or_symbol)
      record_or_symbol.is_a?(Symbol) ? assigns(record_or_symbol) : record_or_symbol
    end
  end #module
end


module ActionController
  class TestCase
    def assert_successful_create(*args)
      crud(*args) do |options|
        #assert_record_saved_and_has_attrs options[:recv], options[:data][options[:send]]
        #assert_record_saved_and_equal_to options[:recv], options[:record].class.find(:first, :order => 'id desc')
        assert_record_saved_and_equal_to options[:recv], options[:record]
      end
    end
    def assert_unsuccessful_create(*args)
      crud(*args) do |options|
        assert_record_new_and_not_valid options[:recv]
      end
    end
    def assert_successful_update(*args)
      crud(*args) do |options|
        orig_record = options[:record]
        updated_record = orig_record.class.find(orig_record.id)
        assert_records_not_equal updated_record, orig_record
        assert_record_saved_and_has_attrs options[:recv], updated_record
      end
    end
    def assert_unsuccessful_update(*args)
      crud(*args) do |options|
        orig_record = options[:record]
        updated_record = orig_record.class.find(orig_record.id)
        assert_records_equal updated_record, orig_record
        # should this be abstracted?
        record = assigns(options[:recv])
        assert_not_nil record
        assert_record_not_new record
        assert_not_valid record
        assert_records_not_equal updated_record, record
      end
    end
    
    def assert_destroy(*args)
      crud(*args) do |options|
        orig_record = options[:record]
        assert_raises(ActiveRecord::RecordNotFound) { orig_record.class.find(orig_record.id) }
      end
    end
    
  private
    def crud(*args)
      options = args.pop
      method = (args.size == 2) ? args.shift : :post
      action = args.shift
      send(method, action, options[:data].dup)
      symbol = options[:recv]
      #assert_record_has_attrs assigns(symbol), options[:record].attributes
      assert_not_nil assigns(symbol)
      #assert_flash symbol, assigns(symbol) if flash.include?(symbol)
      yield(options)
      #if redir = options[:redirect]
      #  redir = { :action => redir } if redir.is_a?(String)
      #  assert_redirected_to redir
      #end
      #assert_response options[:response] if options[:response]
    end
  end
end