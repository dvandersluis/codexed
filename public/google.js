window.gbar={};
(function()
{
  function h(a,b,d)
  {
    var c="on"+b;
    if (a.addEventListener) a.addEventListener(b,d,false);
    else if(a.attachEvent) a.attachEvent(c,d);
    else
    {
      var f=a[c];
      a[c]=function()
      {
        var e=f.apply(this,arguments),g=d.apply(this,arguments);
        return e==undefined?g:g==undefined?e:g&&e
      }
    }
  };
  
  var i=window.gbar,k,l,m;
  
  function n(a,b,d,c,f,e)
  {
    var g=document.getElementById(a);
    if(g)
    {
      var j=g.style;
      j.left=c?"auto":b+"px";
      j.right=c?b+"px":"auto";
      j.top=d+"px";
      j.visibility=l?"hidden":"visible";
      
      if(f&&e)
      {
        j.width=f+"px";
        j.height=e+"px"
      }
      else
      {
        n(k,b,d,c,g.offsetWidth,g.offsetHeight);
        l=l?"":a
      }
    }
  }
  
  i.tg=function(a)
  {
    a=a||window.event;
    var b,d=a.target||a.srcElement;
    a.cancelBubble=true;
    if(k!=null)o(d);
    else
    {
      b=document.createElement(Array.every||window.createPopup?"iframe":"div");
      b.frameBorder="0";
      k=b.id="gbs";
      b.src="javascript:''";
      d.parentNode.appendChild(b);
      h(document,"click",i.close);
      o(d);
      i.alld&&i.alld(function()
      {
        var c=document.getElementById("gbli");
        if(c)
        {
          var f=c.parentNode;
          p(f,c);
          var e=c.prevSibling;
          f.removeChild(c);
          i.removeExtraDelimiters(f,e);
          b.style.height=f.offsetHeight+"px"
        }
      })
    }
  };
  
  function q(a)
  {
    var b,d=document.defaultView;
    if(d&&d.getComputedStyle)
    {
      if(a=d.getComputedStyle(a,""))b=a.direction
    }
    else b=a.currentStyle?a.currentStyle.direction:a.style.direction;
    return b=="rtl"
  }
  
  function o(a)
  {
    var b=0;
    if(a.className!="gb3")a=a.parentNode;
    var d=a.getAttribute("aria-owns")||"gbi",c=a.offsetWidth,f=a.offsetTop>20?46:24,e=false;
    
    do b+=a.offsetLeft||0;
    while(a=a.offsetParent);
    
    a=(document.documentElement.clientWidth||document.body.clientWidth)-b-c;
    c=q(document.body);
    if(d=="gbi")
    {
      var g=document.getElementById("gbi");
      p(g,document.getElementById("gbli")||g.firstChild);
      if(c)
      {
        b=a;e=true
      }
    }
    else if(!c)
    {
      b=a;
      e=true
    }
    
    l!=d&&i.close();
    n(d,b,f,e)
  }
  
  i.close=function()
  {
    l&&n(l,0,0)
  };
  
  function r(a,b,d)
  {
    if(!m)
    {
      m="gb2";
      if(i.alld)
      {
        var c=i.findClassName(a);
        if(c)m=c
      }
    }
    a.insertBefore(b,d).className=m
  }
  
  function p(a,b)
  {
    for(var d,c=window.navExtra;c&&(d=c.pop());)
      r(a,d,b)
  }
})();
