function cancel_event(event)
{
	var evt = event || window.event;
	if (evt.preventDefault) evt.preventDefault();
	else window.event.returnValue = false;
}
