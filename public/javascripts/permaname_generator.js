// This depends on:
// * form_helper.js
// * String#wordTruncate (in admin.js)

PermanameGenerator = Class.create({
  initialize: function(form, modelPrefix, srcAttr, destAttr, options) {
    var options = Object.extend({
      autoUpdatePermaname: true,
      permanameLength: 60
    }, options || {});
    
    this.form = $(form);
    this.modelPrefix = modelPrefix;
    this.srcAttr = srcAttr;
    this.destAttr = destAttr;
    this.autoUpdatePermaname = options.autoUpdatePermaname;
    this.permanameLength = options.permanameLength;
    
    this.srcField = $(this.modelPrefix+"_"+this.srcAttr);
    this.destField = $(this.modelPrefix+"_"+this.destAttr);
    this.autoUpdatePermanameField = $(this.modelPrefix+"_autoupdate_"+this.destAttr);
    
    if (this.form) {
      var self = this;
      $w('keyup change focus blur').each(function(et) {
        self.srcField.observe(et, self.updatePermanameFromTitle.bind(self));
      });
      self.destField.observe('keypress', function(event) {
        var passthru = force_allowed_chars(event, /[a-z0-9-_]/, false, false, function() {
          self.setPermanameUpdating(false);
        });
        if (passthru) force_lowercase(event);
      });
      self.autoUpdatePermanameField.observe('click', function() {
        self.setPermanameUpdating(this.checked)
      })
    }
  },
  updatePermanameFromTitle: function() {
    if (!this.autoUpdatePermaname) return;
    this.destField.value = this.generatePermaname(this.decode(this.srcField.value), { length: this.permanameLength });
  },
  setPermanameUpdating: function(state) {
    this.autoUpdatePermaname = state;
    if (state) this.updatePermanameFromTitle();
    this.autoUpdatePermanameField.checked = state;
  },
  decode: function(string) {
    var decodeTextArea = $('decoded_'+this.destAttr)
    decodeTextArea.innerHTML = string.replace(/</g,"&lt;").replace(/>/g,"&gt;");
    return decodeTextArea.value;
  },
  // This is converted from the Ruby version -- Entry.generated_permaname
  // so see there for updates
  generatePermaname: function(str, options) {
    var options = Object.extend({ sep: "-" }, options || {});
    var str = str.
      // remove HTML tags
      replace(/<\/?[^>]*>/g, "").
      // convert "&" to " and "
      replace(/\s*[&]\s*/g, " and ").
      // -- TODO: translate special dashes here --
      // remove all characters other than alphanumeric, underscore, dash and space
      // since we don't have an uninternationalize in JS, just allow extended latin
      replace(new RegExp('[^a-z0-9\u00C0-\u024F_ '+options.sep+']', "ig"), ""). 
      // replace underscores in between alphanumeric characters with dashes 
      replace(/([a-z0-9])_+([a-z0-9])/ig, '$1' + options.sep + '$2').
      // squeeze multiple spaces
      squeeze(" ").
      // replace spaces with dashes 
      replace(/\s/g, options.sep).
      // squeeze multiple dashes 
      squeeze(options.sep);
    if (options.length)
      // trim the string to the permaname length (but don't cut off any words)
      str = str.wordTruncate(options.length, "-");
    str = str.
      // remove dashes from the start and end of the string
      replace(new RegExp("^"+options.sep+"|"+options.sep+"$", "g"), "").
      // you can probably guess what this does ;)
      toLowerCase();

    return str;
  }
});