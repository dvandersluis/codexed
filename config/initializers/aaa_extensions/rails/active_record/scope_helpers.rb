module ScopeHelpers
  def scope_state(attr, states)
    states.each do |method, state|
      named_scope method, lambda {
        { :conditions => "`#{table_name}`.`#{attr}` = #{state.inspect}" }
      }
      named_scope "not_#{method}", lambda {
        { :conditions => "`#{table_name}`.`#{attr}` != #{state.inspect}" }
      }
      class_eval "def #{method}?; #{attr} == #{state.inspect}; end", __FILE__, __LINE__
    end
  end
end

ActiveRecord::Base.extend(ScopeHelpers)