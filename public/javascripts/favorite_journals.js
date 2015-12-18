function add_favorite_succeeded(request)
{
  var response = request.responseJSON;
  if (response.success == true)
  {
    var tbody = $('fj_tbody');
    var trs = tbody.childElements();
    if (trs[0].id == 'fj_no_favorites') trs.shift();

    $('fj_no_favorites').hide();

    var new_tr = new Element('tr', {id: 'fj_table_row_id' + response.id});
    var new_td1 = new Element('td');
    var new_td1_a1 = new Element('a', {href: '/~' + response.username}).update(response.username);
    var new_td1_a2 = new Element('a', {href: response.url, onclick: "return ajax_request('" + response.url + "', remove_favorite_succeeded, '" + response.authenticity_token + "');"}).update("x");
    var new_td2 = new Element('td', {nowrap: 'nowrap'}).update(response.age).addClassName('fj-age');

    new_td1.insert(new_td1_a1).insert("&nbsp;[").insert(new_td1_a2).insert("]");
    new_tr.insert(new_td1).insert(new_td2);

    if (parseInt(response.order) >= trs.length)
    {
      tbody.insert({bottom: new_tr});
    }
    else
    {
      trs[response.order].insert({before: new_tr});
    }

    new Effect.Highlight(new_tr, {duration: 2.0});

    if (response.merge_action == 'update')
    {
      update_merge_message(response.merge_content);
    }
    else if (response.merge_action == 'remove')
    {
      new Effect.Fade('fj_merge', {duration: 1.0});
    }
  }
  else
  {
    $('fj_error_span').update(response.errors);
    $('fj_error').show();
    setTimeout("new Effect.Fade('fj_error', {duration: 1.0})", 7000);
  }

  $('fj_add_input').clear();
}

function remove_favorite_succeeded(request)
{
  var response = request.responseJSON;

  if (response.success == true)
  {
    tr = $('fj_table_row_id' + response.id);

    new Effect.Highlight(tr, { startcolor: '#EA786B', duration: 2.0 });
    new Effect.Fade(tr, { duration: 2.0, afterFinish: function(effect) {
      effect.element.remove();
      if ($('fj_tbody').childElements().length == 1) $('fj_no_favorites').show();
    }});

    if (response.merge_action == 'update')
    {
      update_merge_message(response.merge_content);
    }
    else if (response.merge_action == 'remove')
    {
      new Effect.Fade('fj_merge', {duration: 1.0});
    }
  }
  else
  {
    $('fj_error_span').update(response.errors);
    $('fj_error').show();
    setTimeout("new Effect.Fade('fj_error', {duration: 1.0})", 7000);
  }
}

function merge_favorites_succeeded(request)
{
  var response = request.responseJSON;

  if (response.success == true)
  {
    var tbody = $('fj_tbody');
    $('fj_no_favorites').hide();
    $('fj_merge').hide();
  
    // Dismiss the merge notification; if the user merges and decides they want to remove one of the merged favorites
    // we shouldn't keep bugging them to merge again.
    var now = new Date();
    var expiresDate = new Date(now.getTime() + (365 * 24 * 3600 * 1000)).toGMTString();
    document.cookie = "dismiss_merge_notice=1;expires=" + expiresDate;

    for (idx in response.favorites)
    {
      var trs = tbody.childElements();
      if (trs[0].id == 'fj_no_favorites') trs.shift();

      favorite = response.favorites[idx];
      var new_tr = new Element('tr', {id: 'fj_table_row_id' + favorite.id});
      var new_td1 = new Element('td');
      var new_td1_a1 = new Element('a', {href: '/~' + favorite.username}).update(favorite.username);
      var new_td1_a2 = new Element('a', {href: favorite.url, onclick: "return ajax_request('" + favorite.url + "', remove_favorite_succeeded, '" + response.authenticity_token + "');"}).update("x");
      var new_td2 = new Element('td').update(favorite.age).addClassName('fj-age');

      new_td1.insert(new_td1_a1).insert("&nbsp;[").insert(new_td1_a2).insert("]");
      new_tr.insert(new_td1).insert(new_td2);

      if (parseInt(favorite.order) >= trs.length)
      {
        tbody.insert({bottom: new_tr});
      }
      else
      {
        trs[favorite.order].insert({before: new_tr});
      }

      new Effect.Highlight(new_tr, {duration: 2.0});
    }
  }
  else
  {
    $('fj_error_span').update(response.errors);
    $('fj_error').show();
    setTimeout("new Effect.Fade('fj_error', {duration: 1.0})", 7000);
  }

  $('fj_add_input').clear();
}

function update_merge_message(content)
{
  $('fj_merge_count_span').update(content.count_text);
  $('fj_merge_link').writeAttribute({href: content.url});
  if (!$('fj_merge').visible()) $('fj_merge').show();
}

function dismiss_merge_message()
{
  var now = new Date();
  var expiresDate = new Date(now.getTime() + (365 * 24 * 3600 * 1000)).toGMTString();
  document.cookie = "dismiss_merge_notice=1;expires=" + expiresDate;
  new Effect.Fade('fj_merge', {duration: 1.0});
}

