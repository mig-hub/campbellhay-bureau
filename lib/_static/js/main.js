// What to do when a new nutshell is created
var new_nutshell_callback = function(s) {
	// Hide delete/clone forms
	$('.btn-delete, .btn-clone', s).prev().hide().find('input[name=_destination]').remove();
	// Hide delete attachment forms
	$('.deletable-image form', s).hide().after("<div class='btn-delete-attachment' title='Delete Attachment'></div>").find('input[name=_destination]').remove();
	// Quick updates from nutshell
	$('.nutshell *[name^=model]', s).change(function() {
	  var arr = $(this).attr('id').split('-');
		var update_url = cms_path+'/'+arr[1]+'/'+arr[0]
		$.ajax({
			url: update_url, 
			data: $(this).parents('form').serialize(),
			type: 'PUT'
		});
	});
	// Scene selector
	var selectable_scene = $('.mapolygon-me');
	$('.nutshell', s).hover(function() {
	  var $this = $(this);
	  if ($this.data().sceneSelectorCoordinates!='' && selectable_scene.data().dots=='') selectable_scene.trigger('show.mapolygon', [$this.data().sceneSelectorCoordinates.split(',')]);
	}, function() {
	  var $this = $(this);
	  if ($(this).data().sceneSelectorCoordinates!='' && selectable_scene.data().dots=='') selectable_scene.trigger('reset.mapolygon');
	});
};

var new_nut_tree_callback = function(s) {
  var $$ = $(s);
  
  var search_opts = {
	  onAfter: function() {
	    if ($('.search input[type=search]', s).val()=='') {
	      $('.sortable-handle', s).show();
	    } else {
	      $('.sortable-handle', s).hide();
	    }
	  }
	}
	var qs = $('.search input[type=search]', s).quicksearch($$.find(".nutshell"), search_opts);
	$$.data('quicksearch', qs);
  
  // Drop from minilist
  var tree = $('.nut-tree', s);
  tree.droppable({
    accept: '.minilist li',
		drop: function( e, ui ) {
			var id = ui.draggable.attr('id').substring(5);
			var params_sample = ui.draggable.parents('.many-to-many-picker').attr('rel');
			var params = params_sample + id;
			var path = cms_path + '/' + this.id;
			$.post(path, params, function() {
			  $$.trigger('reload_nut_tree.cms');
			  ui.draggable.css({opacity: 0.5});
			  //ui.draggable.addClass('selected');
			});
		}
	});
  
  // Sortable
	$('.sortable', s).sortable({
		stop: function() { $.ajax({
			url: $(this).attr('rel'), 
			data: $(this).sortable('serialize'),
			type: 'PUT'
		});
		},
		items: '.nutshell',
		handle:'.sortable-handle'
	});
  
  new_nutshell_callback(s);
};

// What to do when a new slide is pushed on the stack
var pushstack_callback = function(s, reloading) {
	var $$ = $(s);
	
	// Bind Return callbacks
	// unless it's a reload
	if (!reloading) {
		$$
		.bind('reload.cms', function() {
			$$.find('.slide-inner').load($$.data('reload_path'), function() {
				pushstack_callback(s,true);
				$$.scrollTop($$.data('scrolltop'));
			});
		})
		.bind('reload_nut_tree.cms', function() {
		  $.get($$.data('reload_path'), function(data) {
		    $$.find('.nut-tree').html($("<div>"+data+"</div>").find('.nut-tree').html());
		    new_nut_tree_callback(s);
				$$.scrollTop($$.data('scrolltop'));
		  });
		})
		.bind('register_return.cms', function(e,launcher,cb) {
			$$.data('cb',cb).data('cb_launcher',launcher).data('scrolltop', $$.scrollTop());
		})
		.bind('clean_return.cms', function() {
			$$.removeData('cb').removeData('cb_launcher');
		})
		.bind('return.cms', function(e,data) {
			$$.scrollTop($$.data('scrolltop'));
			var cb = $$.data('cb');
			var cb_launcher = $$.data('cb_launcher');
			if (cb) cb($$,cb_launcher,data);
			$$.trigger('clean_return.cms');
			$$.removeData('scrolltop'); // Seperated because the cancel button should trigger the scrolltop
			$$.data('quicksearch').cache();
		});
	}
	
	// HTML EDITOR
	// textarea tag needs to be specified because the iframe copy the class, so we need to avoid endless nesting
	$('textarea.underwood_editor', s).underwood({sanitize: false}).hide();
	$('textarea.underwood_editor_full', s).underwood({toolbar: 'title paragraph bold italic link mailto unlink image source', sanitize: false}).hide();
	$('textarea.underwood_editor_no_title', s).underwood({toolbar: 'bold italic link mailto unlink source', sanitize: false}).hide();
	
	// Permalink dropdowns
	$('.permalink-dropdown', s).change(function() {
		var $select = $(this);
		$select.parent().find('input').val($select.val());
	});
	
	// Date/Time pickers
	$('.datepicker', s).datepicker({dateFormat: 'yy-mm-dd'});
	$('.timepicker', s).timepicker({showSecond: true,timeFormat: 'hh:mm:ss'});
	$('.datetimepicker', s).datetimepicker({showSecond: true,dateFormat: 'yy-mm-dd',timeFormat: 'hh:mm:ss'});
	
	// Multiple select with asmSelect
	$(".asm-select", s).asmSelect({ sortable: true });
	
	// Back btn
	if ($$.is('.inserted-slide')) {
		// var commands = $$.find('.nut-tree-commands');
		//    if (commands.size()>0) {
		//      commands.prepend("<a class='pop-stack btn btn-back' href='javascript:;' title='Back'></a>");
		//    } else {
		//      $$.find('.slide-inner').prepend("<div class='nut-tree-commands'><a class='pop-stack btn btn-back cancel' href='javascript:;' title='Back'></a></div>");
		//    }
		$$.find('.slide-inner').prepend("<a class='pop-stack top-pop-stack' href='javascript:;'>"+ $$.prev().find('.slide-title > span').text() +"<span>go back up<span class='btn btn-back'></span></span></a>");
	}
	
	// Reload btn
	$('.btn-reload', s).click(function() {
		$$.trigger('reload.cms');
		return false;
	});
	
	// JS Search
	$('.search :submit', s).hide();
	$('.search', s).submit(function() { return false; });
	
	// Minilist
	$('.many-to-many-picker .minilist-wrapper', s).frise()
	.bind('fix_width.cms', function() {
	  var $this = $(this);
	  var ul = $this.children(':first');
	  var elts = $this.find('li:visible');
	  var elt = ul.children(':first');
	  var gutter = parseInt(elt.css('margin-right'));
	  var w = elts.size() * elt.width() + elts.size() * gutter;
	  ul.width(w);
	})
	.trigger('fix_width.cms');
  $('.many-to-many-picker .minilist-wrapper li', s).draggable({
   appendTo: 'body',
   //axis: "y",
   revert: 'invalid', // when not dropped, the item will revert back to its initial position
   helper: function(e) { return $("<div class='minilist-dragged'>"+$(this).html()+"</div>") },
   cursor: "move"
  });
	
	//Minilist quicksearch
	search_opts = {
	  onAfter: function() {
	    $('.many-to-many-picker .minilist-wrapper', s).trigger('fix_width.cms');
	  }
	}
	$('.minisearch', s).quicksearch($$.find(".minilist li"), search_opts);
	
	// Scene selector
	var selectable_scene = $('.mapolygon-me', s);
	selectable_scene.mapolygon(function(data,img) {
	  if (data.length>0) $('.scene-selector-toolbar',s).fadeIn();
	});
	$('.reset-mapolygon', s).click(function() {
	  selectable_scene.trigger('reset.mapolygon');
	  $('.scene-selector-toolbar',s).fadeOut();
	});
	$('.save-mapolygon', s).click(function() {
	  this.href = this.href+selectable_scene.data().dots.join(',');
	});
	
	// Ajaxify forms
	if ($$.is('.inserted-slide')) {
		$$.find('input[name=_destination]').remove();
		$f = $$.find(':submit').parents('form').not('.search');
		$f.filter('.backend-form').has(':submit[value=SAVE]').append(" or <a href='javascript:;' class='pop-stack cancel'>CANCEL</a>");
		$f.submit(function() { // Model form or search
			var $form = $(this);
			$form.find(':submit').prop('disabled',true).after("<img src='"+cms_path+"/_static/img/small-loader.gif' />");
			$form.ajaxSubmit({
				success: function(data) {
					if (data=='OK' || !!data.match(/\bOK\b/i)) { // Success
            console.log('data ok');
						$slides.trigger('pop.cms', [data]);
					} else {
            console.log('data not ok');
						$$.children().html(data);
            // if ($form.is('.search')) {
            //  var url = $form.attr('action') + ($form.attr('action').indexOf('?')+1 ? '&' : '?') + $form.serialize();
            //  $$.data('reload_path', url);
            // }
						pushstack_callback($$);
					}
				}
			});
			return false;
		});
	}
	
	new_nut_tree_callback(s);
	
	// Custom
	if (typeof custom_pushstack_callback == 'function') custom_pushstack_callback(s); // Write this method in order to add some custom editors
};

// Return callbacks
var form_callback = function(slide,launcher,data) {
	var $slide = $(slide);
	var $launcher = $(launcher);
	var $data = $(data);
	if ($launcher.is('.btn-edit')) {
		$launcher.parents('.nutshell').before($data).remove();
	} else {
		$('.nut-tree', slide).prepend($data);
	}
	new_nutshell_callback($data);
	//$data.hide().fadeIn('slow'); // Fucks the fact that scroll is getting to its prev position
};

var default_callback = function(slide,launcher,data) {
	// Just reload the slide until a better callback is created
	$(slide).trigger('reload.cms');
};

$(function() {
	
	// Stack
	$slides = $('#slides');
	$slides
	.bind('push.cms', function(e, data, url) {
		var last = $("<div class='slide inserted-slide'><div class='slide-inner'>"+data+"</div></div>").appendTo($(this));
		last.data('reload_path', url);
		var previous = last.prev();
		$slides.animate({top: -$(window).height()+'px'}, function() {
			previous.hide();
			$slides.css({top: '0px'});
			pushstack_callback(last);
		});
	})
	.bind('pop.cms', function(e, data) {
		var last = $('.inserted-slide:last');
		last.fadeOut('fast', function() {
			var called = last.prev().show();
			last.remove();
			$slides.css({top: -$(window).height()+'px'});
			$slides.animate({top: '0px'}, function() {
				called.trigger('return.cms', [data]);
			});
		});
	});
	
	// Links pushing stack
	$('a.push-stack').live('click', function(e) {
		var cb = $(this).is('.sublist-link') ? default_callback : default_callback; // will change in time
		$(this).parents('.slide').trigger('register_return.cms', [this,cb]);
		var url = this.href.replace(/(_no_wrap=true|_destination=[^&]*)/g, '');
		$.get(url, function(data) {
			$slides.trigger('push.cms', [data, url]);
		});
		return false;
	});
	
	// Links Pop Stack without callback
	$('.pop-stack').live('click', function() { 
		if ($(this).is('.cancel')) $(this).parents('.slide').prev().trigger('clean_return.cms');; 
		$slides.trigger('pop.cms'); 
		return false;
	});
	
	// Ajax delete
	$('.btn-delete').live('click', function() {
		if (confirm('This action is irreversible. Are you sure you want to delete this entry ?')) {
			var $btn = $(this);
			var $form = $btn.prev();
			$.ajax({
				url: $form.attr('action'), 
				data: $form.serialize(),
				type: 'DELETE',
				success: function() { $btn.parents('.nutshell').fadeOut(function() { $(this).remove(); }); }
			});
		}
	});
	
	// Ajax delete attachment
	$('.btn-delete-attachment').live('click', function() {
		if (confirm('This action is irreversible. Are you sure you want to delete this attachment ?')) {
			var $btn = $(this);
			var $form = $btn.prev();
			$.ajax({
				url: $form.attr('action'), 
				data: $form.serialize(),
				type: 'PUT',
				success: function() { $btn.parents('.deletable-image').fadeOut(); }
			});
		}
	});
	
	// Ajax clone
	$('.btn-clone').live('click', function() {
    if (confirm('This will create a new entry with similar values. Do you want to proceed ?')) {
  		var $btn = $(this);
  		var $form = $btn.prev();
  		var $slide = $btn.parents('.slide')
  		$.post($form.attr('action'), $form.serialize(), function(data) {
  			if (data=='OK') {
  				$slide.trigger('reload.cms');
  				if ($btn.parents('.sortable').size()==0) $slide.animate({ scrollTop: $slide.height() });
  			}
  		});
    }
	});
	
	pushstack_callback($('#content').data('reload_path', document.location.href));
	
	// Tooltips
	$.speechify({
		backgroundColor: '#00ABC4', 
		color: 'black',
		'border-radius': '0px', 
		'-moz-border-radius': '0px',
		'-webkit-border-radius': '0px',
		'-webkit-box-shadow': '0px 0px 5px rgba(0,0,0,0.5)'
	});
});
