ActiveRecord::ConnectionAdapters::SchemaStatements.module_eval do       
  def type_to_sql_with_custom_type(type, *params)
    return type unless native_database_types.has_key? type
    type_to_sql_without_custom_type(type, *params)
  end
  alias_method_chain :type_to_sql, :custom_type      
end
