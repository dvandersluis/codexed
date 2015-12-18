// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
function $S(index)
{
  index = document.styleSheets[index];
  Object.extend(index, {addCSS : function(seletor,rule) {
      if (this.insertRule)
      this.insertRule(seletor + '{'+rule+'}', this.cssRules.length);
      else if (this.addRule)
      this.addRule(seletor, rule, this.rules.length)
    }
  });
  return Element.extend(index);
}

function dismiss_nag_notice(type)
{
  var now = new Date();
  var expiresDate = new Date(now.getTime() + (365 * 24 * 3600 * 1000)).toGMTString();
  document.cookie = "dismiss_" + type + "_nag_notice=1;expires=" + expiresDate + ";path=/";
  $('nag_notice').slideUp({ duration: 0.5 });
}
