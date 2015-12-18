class TemplateSweeper < ActionController::Caching::Sweeper
  observe Template, Prefab
  
  def after_save(template)
    expire_cache_for(template)
  end

  def after_destroy(template)
    expire_cache_for(template)
  end

private
  def expire_cache_for(record)
    # For templates, we need to find all the entries that use the template and expire them
    # We also need to take the default template into account (sweep pages that use the default template
    # when the default template is changed)

    journal = record.journal

    entries = journal.entries.find_all_by_template_id(record.id).to_a
    entries += journal.entries.find_all_by_template_id(nil).to_a if record.default? || record.make_default?

    base_path = "/users/" + journal.user.username + "/"

    entries.each do |entry|
      expire_page(base_path + entry.url(true))
    end

    # Expire the start page if necessary
    if journal.start_page and (journal.start_page.template_id == record.id or (journal.start_page.template_id.nil? and (record.default? || record.make_default?)))
      expire_page(base_path)
    end
  end
end
