if (!Function.prototype.debounce)
{
  Function.prototype.debounce = function(threshold, execAsap)
  {
      var func = this, timeout;
      if (execAsap !== true) execAsap = false;
   
      return function debounced()
      {
          var obj = this, args = arguments;
          function delayed()
          {
              if (!execAsap)
                  func.apply(obj, args);
              timeout = null; 
          };
   
          if (timeout) clearTimeout(timeout);
          else if (execAsap) func.apply(obj, args);
   
          timeout = setTimeout(delayed, threshold || 100); 
      };
  }
}

// Resize the div that holds the prefab divs based on the screen width
var resize_container = function()
{
  var main, container, cell_width;

  return function resizer()
  {
    if (!main) main = $('main');
    if (!container) container = $('prefabs');
    if (!cell_width) cell_width = $$('div.prefab_container')[0].measure('padding-box-width');
    var main_width = main.measure('padding-box-width');
    container.style.width = cell_width * Math.floor(main_width / cell_width) + "px";
  };
}();

// Re-organizes prefabs based on the new sort order
function resort(mode, fade)
{
  function do_sort()
  {
    if (orders[mode])
    {
      orders[mode].each(function(div)
      {
        parent.appendChild($(div));
      });
      location.hash = mode;
    }
  }

  var parent = $('prefabs');
  if (fade !== false) fade = true;

  if (fade)
  {
    parent.fade({ duration: 0.3, from: 1, to: 0.3, afterFinish: do_sort })
          .fade({ duration: 0.3, from: 0.3, to: 1, queue: 'end' })
  }
  else
  {
    do_sort();
  }

}

document.observe("dom:loaded", function()
{
  var hash = location.hash.substr(1);
  if (hash && orders[hash])
  {
    resort(hash, false);  
    $('sort_' + hash).checked = true;
  }

  $('sort_by_button').hide();

  resize_container();
});

Event.observe(document.onresize ? document : window, "resize", resize_container.debounce(100));
