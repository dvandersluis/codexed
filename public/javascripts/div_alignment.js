function centerDiv(elem)
{
  var elem = $(elem);
  var winDims = document.viewport.getDimensions();
  var elemDims = elem.getDimensions();
  var top  = ((winDims.height / 2) - (elemDims.height / 2));
  // visually this looks better, as centering it perfectly creates an optical illusion
  // that looks like it's too far down
  top -= winDims.height * 0.08;
  var left = ((winDims.width / 2)  - (elemDims.width / 2));
  elem.style.position = 'absolute';
  elem.style.top = top + 'px';
  elem.style.left = left + 'px';
}

function centerDivWithin(elem, box)
{
  var elem = $(elem);
  var box = $(box);
  
  var elemDims = elem.getDimensions();
  var boxDims = box.getDimensions();
  var boxOffset = box.cumulativeOffset();
  var winDims = document.viewport.getDimensions();
  var scrollOffset = document.viewport.getScrollOffsets();
  
	// get the real offset of the bottom edge of the window
  var bottomOffset = scrollOffset.top + winDims.height;
	// vertical distance of the part of the box that's visible onscreen
  var visibleBoxHeight = bottomOffset - boxOffset.top;
	// don't ask me how I calculated this
  var top = ((visibleBoxHeight / 2) + boxOffset.top) - (elemDims.height / 2);
	// adding 10 looks better (TODO: this should probably be changed to a percentage)
  if (top < boxOffset.top) top = boxOffset.top + 10;
	// just like centerDiv() above
  var left = (boxDims.width / 2) - (elemDims.width / 2);

  e1.style.position = 'absolute';
  e1.style.top = top + 'px';
  e1.style.left = left + 'px';
}