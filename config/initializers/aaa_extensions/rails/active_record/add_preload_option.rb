# Patch ActiveRecord so that association preloading can be disabled for a specific query
# CAVEAT: Don't use :preload => false with :joins and the selectable_includes plugin.
#         Doing so causes :joins to act like :include (the :select clause is prepended just like for :include).
class ActiveRecord::Base
  class << self
    VALID_FIND_OPTIONS << :preload
    
    def find_every(options)
      include_associations = merge_includes(scope(:find, :include), options[:include])

      if options[:preload] === false || (include_associations.any? && references_eager_loaded_tables?(options))
        records = find_with_associations(options)
      else
        records = find_by_sql(construct_finder_sql(options))
        if include_associations.any?
          preload_associations(records, include_associations)
        end
      end

      records.each { |record| record.readonly! } if options[:readonly]

      records
    end
  end
end