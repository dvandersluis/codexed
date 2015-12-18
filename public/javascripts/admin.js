// Add some String methods
Object.extend(String.prototype, {
  ltrim: function(charset)
  {
    if (!charset) charset = "\\s";
    if (charset instanceof RegExp)
    {
      charset = charset.source;
    }
    return this.replace(new RegExp("^(" + charset + ")*", "g"), "");
  },

  rtrim: function(charset)
  {
    if (!charset) charset = "\\s";
    if (charset instanceof RegExp)
    {
      charset = charset.source;
    }
    return this.replace(new RegExp("(" + charset + ")*$", "g"), "");
  },

  trim: function(charset)
  {
    return this.ltrim(charset).rtrim(charset);
  },
  
  squeeze: function(char) {
    return this.replace(new RegExp(char+'+', "g"), char);
  },
  
  wordTruncate: function(length, separator/*=" "*/) {
    if (this.length <= length) return this;
    var separator = separator || "[ ]";
    var re = new RegExp(separator + "\\w+$")
    // trim to length
    // then, if we end up in the middle of a word, chop off the rest of the word
    return this.substring(0, length).replace(re, '');
  }
  
});
