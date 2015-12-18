function toggleDateInputs(state) {
  $$('.date_inputs input[type=text], .date_inputs select').invoke(state ? 'enable' : 'disable');
}

document.observe("dom:loaded", function() {
  window.pg = new PermanameGenerator("entry_form", "post", "title", "permaname", {
    autoUpdatePermaname: new_record,
    permanameLength: permaname_length 
  });
  
  var tags_control = new ProtoMultiSelect('post_tag_names', 'tag_autocomplete', {
    newValues: true,
    regexSearch: false,
    fetchFile: tags_fetch_file, 
    results: 5,
    sortResults: true,
    autoResize: true,
    autoDelay: 0,
    defaultMessage: tags_default_message,
    encodeEntities: true
  });

  if ($('post_category_ids_table'))
  {
    $('post_category_ids_table').select('tr').each(function(tr)
    {
      tr.observe('click', function(e)
      {
        if (e.findElement().nodeName.toUpperCase() == "INPUT") return;
        var checkbox = this.select('input[type=checkbox]')[0];
        checkbox.checked = !checkbox.checked;
      });
    });
  }

  $("use_server_time").observe("change", function() {
    toggleDateInputs(!this.checked)
  });
  toggleDateInputs(!$("use_server_time").checked);
  
  $("more_fields_toggler").observe("click", function() {
    if (this.hasClassName("closed")) {
      this.removeClassName("closed").addClassName("open");
    } else {
      this.removeClassName("open").addClassName("closed");
    }
    new Effect.toggle("more_fields", "slide", { duration: 0.2 });
  });
  var entryForm = $$(".entry_form").first() || $$(".page_form").first();
  if (entryForm.hasClassName('valid')) {
    $("more_fields_toggler").removeClassName("open").addClassName("closed")
    $("more_fields").hide();
  }
})
