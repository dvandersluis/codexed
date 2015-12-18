// Here's how to make use of restful_destroy:
//
// 1. Ensure that you have a route set up for your resource's delete action: :member => { :delete => :get }
// This page should have a confirmation message and a form that sends a DELETE to /destroy.
// 2. In your view, instead of saying:
//    link_to("whatever", foo_path(foo), :method => :delete, :confirm => "Are you sure?"),
// say this instead:
//    link_to("whatever", delete_foo_path(foo), :class => 'delete', :title => "Are you sure?")
// 3. To counter InvalidAuthenticityToken errors when the delete link is clicked, we need to pass along the
// form authenticity token. So put this somewhere in your view (or perhaps layout):
//    <script type="text/javascript">
//      window.requestForgeryProtectionToken = "<%= request_forgery_protection_token %>";
//      window.formAuthenticityToken = "<%= escape_javascript form_authenticity_token %>";
//    </script>
// 4. Include restful_destroy.js in your view that has the delete link, and all links with a class of 'delete'
// will be automatically changed so that clicking on them will show a confirm popup box and DELETE to /destroy.
// If Javascript is not enabled then this falls back to the 'delete' action.

document.observe("dom:loaded", function() {
  $$("a.delete").each(function(link) {
    link.observe('click', function(event) {
      var msg = link.readAttribute("title");
      if (confirm(msg)) {
        var action = link.readAttribute("href").replace(/\/delete$/, "");
        var f = new Element("form", { style: "display: none", method: 'post', action: action });
        var m = new Element("input", { type: "hidden", name: "_method", value: "delete" });
        var t = new Element("input", { type: "hidden", name: window.requestForgeryProtectionToken, value: window.formAuthenticityToken })
        f.appendChild(m);
        f.appendChild(t);
        link.parentNode.appendChild(f);
        f.submit();
      }
      event.stop();
    })
  })
})
