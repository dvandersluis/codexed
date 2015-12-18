// Codexed extension for Reblogger which trims keys

if (!String.prototype.trim)
{
  String.prototype.trim = function()
  {
    return this.replace(/^\s*|\s*$/, "");
  }
}

if (pCount)
{
  for (var i in pCount)
  {
    if (pCount.hasOwnProperty(i))
    {
      var new_key = i.toString().trim();
      pCount[new_key] = pCount[i];
      if (i !== new_key)
      {
        delete pCount[i];
      }
    }
  }
}

var originalPostCount = postCount;
var originalRebloggerLink = rebloggerLink;
var originalOnpageReblogger = onpageReblogger;

postCount = function(pre, item, post)
{
  originalPostCount(pre, item.toString().trim(), post);
};

rebloggerLink = function(item)
{
  originalRebloggerLink(item.toString().trim());
}

onpageReblogger = function(item)
{
  originalOnpageReblogger(item.toString().trim());
}
