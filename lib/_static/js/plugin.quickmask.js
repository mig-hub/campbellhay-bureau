;(function($) {
  
	$.fn.quickmask = function() {
	  return this.each(function() {
	    var mask = $(this).css({overflow: 'hidden'});
	    var target = mask.children(':first');
	    mask.mousemove(function(e) {
	      var mask_width = mask.width();
	      var mask_height = mask.height();
	      var target_width = target.width();
	      var target_height = target.height();
	      if (target_width>mask_width) {
	        var left = (e.pageX - mask.offset().left) * (target_width-mask_width) / mask_width;
	        mask.scrollLeft(left);
        }
        if (target_height>mask_height) {
	        var top = (e.pageY - mask.offset().top) * (target_height-mask_height) / mask_height;
          mask.scrollTop(top);
        }
	    });
	  });
	};
	
	function is_touch_device() {  
    try {  
      document.createEvent("TouchEvent");  
      return true;  
    } catch (e) {  
      return false;  
    }  
  }
	
	$.fn.frise = function() {
	  var opts = {
	    zone_width: 100,
	    low_speed: 20,
	    high_speed: 40
	  };
	  
	  return this.each(function() {
	    var $this = $(this).css({overflow: 'hidden'});
	    var target = $this.children(':first');
	    var frise_interval;
	    var frise_speed;
	    var frise_direction;
	    var frise_move = function() {
	      $this.scrollLeft($this.scrollLeft()+frise_speed*frise_direction);
	    };
	    $this
	    .mouseenter(function() { frise_interval = setInterval(frise_move, 50); })
	    .mouseleave(function() { clearInterval(frise_interval); })
	    .mousemove(function(e) {
	      var e_pageX = e.pageX - $this.offset().left;
	      if (e_pageX>0 && e_pageX<opts.zone_width) {
          frise_speed = opts.low_speed;
          frise_direction = -1;
        } else if (e_pageX>($this.width()-opts.zone_width) && e_pageX<$this.width()) {
          frise_speed = opts.low_speed;
          frise_direction = 1;
        } else {
          frise_speed = 0;
        }
	    });
	  });
	  
	};
	
})(jQuery);