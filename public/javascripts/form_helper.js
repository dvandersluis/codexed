/*
Usage:	Only allows specified characters to be added to the input.
Params:	event - this function takes an event object as
				a parameter. In order to pass that, call force_allowed_chars() from a event
        handler function. You can call it from an onxxxx call by using the form
				onxxxx="force_allowed_chars(event, ...)".
				Consider writing a wrapper which contains this function.
		charset - the string of allowed characters.
		case_sensitive - A boolean flag (true or false) specifying whether the charset is case
				sensitive or not. [OPTIONAL -- defaults to true]
    fn - Code to run if the input is allowed [OPTIONAL -- defaults to null]
Dependencies: cancel_event.js
Note:	Control characters (enter, backspace, delete, F-keys, etc.) and CTRL/ALT sequences
		are always let through.
*/
function force_allowed_chars(event, charset, case_sensitive /*=true*/, return_on_delete /*=true*/, fn /*=null*/)
{
	// Initialize default values if necessary:
	if (case_sensitive !== false) case_sensitive = true;
  if (return_on_delete !== false) return_on_delete = true;
  if (typeof fn != "function") fn = null;

	var evt = event ? event : window.event;
	if (evt.ctrlKey || evt.altKey || evt.metaKey) return false;
	if (evt.keyCode != 0 && evt.keyCode != 46 && evt.which == 0) return false;

	var keyCode = evt.which ? evt.which : evt.keyCode;
	if (keyCode == 13) return false; // Trap Enter
	var keyChar = String.fromCharCode(keyCode);

  if (keyCode == 8 || (evt.keyCode == 46 && evt.which == 0))
  {
    if (return_on_delete)
    {
      // Trap backspace & delete
      return false;
    }
    else
    {
      if (fn) fn();
      return true;
    }
  }

  if (charset instanceof RegExp)
  {
    if (!case_sensitive)
    {
      charset = new RegExp(charset.source, "i");
    }

    var invalid_char = !charset.test(keyChar);
  }
  else
  {
    if (!case_sensitive)
    {
      charset = charset.toUpperCase();
      keyChar = keyChar.toUpperCase();
    }
    
    var invalid_char = (charset.indexOf(keyChar) == -1);
  }

  if (invalid_char)
  {
    cancel_event(evt);
    return false;
  }
  
  if (fn) fn();
	return true;
}

function force_case(event, casetype)
{
  casetype = casetype.toUpperCase();
  if (casetype != "U" && casetype != "L") return;

	var evt = event || window.event;
	var keyCode = evt.keyCode || evt.which;
	var keyChar = String.fromCharCode(keyCode);
	var target = evt.target || evt.srcElement;

	if (evt.ctrlKey || evt.altKey) return;
	if (evt.keyCode != 0 && evt.which == 0) return;
	if (!keyChar.match(/[a-z]/i)) return;
	if (target.value.length == $(target).readAttribute("maxlength")) return;
	
	// Generally, the only way to replace a key input is to replace the value of the input with
	// the new value (the event object has a keyCode property which specifies what key was pressed, but
	// it is only mutable in IE). Here the enterred key is replaced (seamlessly), and the cursor
	// maintains its position.
	if (target.setSelectionRange)
	{
		cancel_event(evt);
	
		// Save the cursor / selection positions:
		var start = target.selectionStart;
		var end = target.selectionEnd;
	  var insert = casetype == "U" ? keyChar.toUpperCase() : keyChar.toLowerCase()
		
		// Replace the target value and put the cursor after the replaced character:
		target.value =
			target.value.substring(0, start) + insert + target.value.substring(end);
		target.setSelectionRange(start + insert.length, start + insert.length);
	}
	else if (window.event) // If we're in IE, we can just change the event keycode.
	{
		window.event.keyCode = casetype == "U" ? keyChar.toUpperCase().charCodeAt() : keyChar.toLowerCase().charCodeAt()
	}
}

function force_lowercase(event)
{
  return force_case(event, "L")
}

function force_uppercase(event)
{
  return force_case(event, "U")
}
