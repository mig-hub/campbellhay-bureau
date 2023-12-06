require 'bureau/adapter'

module ::Sequel::Plugins::BureauAdapter
  
  def self.configure(model, opts = {})
    model.bureau_config = opts
    model.crushyform_types.update({
      :autocomplete => proc do |instance, column_name, options|
        values = model.select(column_name).exclude(column_name=>'').map(column_name)
        values = values.inject([]){|s,l| s+l.split(/\s*,\s*/)} if options[:autocomplete_multiple]
        values.uniq.compact!
        tag = model.crushyform_types[:string].call(instance, column_name, options)
        return tag if values.empty?
        unless options[:autocomplete_multiple]
          js = <<-EOJS
          <script type="text/javascript" charset="utf-8">
            $(function(){
              $( "##{instance.crushyid_for(column_name)}" ).autocomplete({source: ["#{values.join('","')}"]});
            });
          </script>
          EOJS
        else
          js = <<-EOJS
          <script type="text/javascript" charset="utf-8">
            $(function(){
              $( "##{instance.crushyid_for(column_name)}" )
              .bind( "keydown", function( event ) {
              	if ( event.keyCode === $.ui.keyCode.TAB &&
              	$( this ).data( "autocomplete" ).menu.active ) {
              		event.preventDefault();
              	}
              })
              .autocomplete({
              	minLength: 0,
              	source: function( request, response ) {
              		response($.ui.autocomplete.filter(["#{values.join('","')}"], request.term.split(/,\s*/).pop()));
              	},
              	focus: function() { return false; },
              	select: function( event, ui ) {
              		var terms = this.value.split(/,\s*/);
              		terms.pop();
              		terms.push(ui.item.value);
              		terms.push("");
              		this.value = terms.join( ", " );
              		return false;
              	}
              });
            });
          </script>
          EOJS
        end
        tag+js
      end,
      :permalink => proc do |instance, column_name, options|
        values = "<option value=''>Or Browse the list</option>\n"
        tag = model.crushyform_types[:string].call(instance, column_name, options)
        return tag if options[:permalink_classes].nil?
        options[:permalink_classes].each do |sym|
          c = Kernel.const_get sym
          entries = c.all
          unless entries.empty?
            values << "<optgroup label='#{c.human_name}'>\n"
            entries.each do |e|
              values << "<option value='#{e.permalink}' #{'selected' if e.permalink==options[:input_value]}>#{e.to_label}</option>\n"
            end
            values << "</optgroup>\n"
          end
        end
        "#{tag}<br />\n<select name='__permalink' class='permalink-dropdown'>\n#{values}</select>\n"
      end
    })
  end
  
  module ClassMethods
    
    include Bureau::Adapter::ClassMethods
    
    attr_accessor :list_options
    
    def list_view(r)
      @list_options={:request=>r, :destination=>r.fullpath, :path=>r.script_name }
      # symbolize keys of filter
      unless r['filter'].nil?
        @list_options[:filter] = {}
        r['filter'].each do |key,value|
          @list_options[:filter][key.to_sym] = value
        end
      end
      @list_options.store(:search, r['q'].scan(/\w+/).map {|w| "%#{w}%"}) unless r['q'].to_s==''
      @list_options.store(:sortable,sortable_on_that_page?)
      o = @list_options

      out = list_view_header
      out << scene_selector unless bureau_config[:scene_selector_class].nil?
      out << many_to_many_picker unless bureau_config[:minilist_class].nil?
      out << "<ul class='nut-tree #{'sortable' if o[:sortable]} #{bureau_config[:nut_tree_class]}' id='#{self.name}' rel='#{o[:path]}/#{self.name}'>"
      
      ds = self
      ds = ds.filter(o[:filter]) unless o[:filter].nil?
      ds = ds.grep(text_columns, o[:search], {:all_patterns=>true, :case_insensitive=>true}) unless (o[:search].nil? || o[:search].empty?)
      ds.all {|e| out << e.to_nutshell }
      
      out << "</ul>"
      out
    end
    
    def foreign_key_name plural 
      "#{underscore(demodulize(name))}_id#{'s' if plural}" 
    end

    def human_plural_name; self.table_name.to_s.tr('_', ' ').gsub(/(['\w]+)/) {|s| "#{s.capitalize}"}; end
    def text_columns; crushyform_schema.inject([]){|a,(k,v)| a<<k if [:text,:string,:autocomplete,:permalink,:select].include?(v[:type]);a}; end
    
    def sortable_on_that_page?
      o = @list_options
      o[:search].nil? && respond_to?(:position_field) && (o[:filter]||{}).keys==[bureau_config[:position_scope]].compact 
    end
    
    def minilist_view
      o = "<ul class='minilist'>\n"
      self.all do |m|
        thumb = m.respond_to?(:to_bureau_thumb) ? m.to_bureau_thumb('stash_thumb.gif') : m.placeholder_thumb('stash_thumb.gif')
        o << "<li title='#{m.to_label}' id='mini-#{m.id}'>#{thumb}<div>#{m.to_label}</div></li>\n"
      end
      o << "</ul>\n"
    end
    
    def scene_selector
      "Not yet implemented for Sequel. See Mongo implementation. And do not forget to implement instance.scene_selector_coordinates."
    end
    
  end
  
  module InstanceMethods
    
    include Bureau::Adapter::InstanceMethods
    
    def in_nutshell
      o = model.list_options
			out = "<div class='in-nutshell'>\n"
			out << self.to_bureau_thumb('nutshell.jpg') if self.respond_to?(:to_bureau_thumb)
			nutshell_backend_columns.select{|col| [:boolean,:select].include?(model.crushyform_schema[col][:type]) }.each do |c|
			  column_label = c.to_s.sub(/_id$/, '').tr('_', ' ').capitalize
			  out << "<div class='quick-update'><form><span class='column-title'>#{column_label}:</span> #{self.crushyinput(c)}</form></div>\n"
		  end
			out << "</div>\n"
    end
    
    def nutshell_children
      o = model.list_options
      out = ""
      nutshell_backend_associations.each do |ass|
			  ass_ref = model.association_reflection(ass)
			  link = "#{o[:path]}/list/#{ass_ref[:class_name]}?filter[#{ass_ref[:key]}]=#{self.id}"
			  text = ass_ref[:nutshell_link_text] || "#{ass.to_s.tr('_', ' ').split.map{|s|s.capitalize}.join(" ").sub(/s$/,'(s)')}"
			  out << "<a href='#{link}' class='push-stack sublist-link nutshell-child'>#{text} #{self.__send__(ass.to_s+'_dataset').count}</a>\n"
		  end
		  out
    end
    
    def nutshell_backend_associations
		  @nutshell_backend_associations ||= model.associations.select do |ass|
		    t = model.association_reflection(ass)[:type]
		    t!=:many_to_one && t!=:many_to_many
	    end
    end
    
    def generic_thumb(img , size='stash_thumb.gif', obj=self)
      current = obj.__send__(img)
      if !current.nil? && current[:type][/^image\//]
        "<img src='#{obj.file_url(img, size)}?#{::Time.now.to_i.to_s}' />\n"
      else
        placeholder_thumb(size)
      end
    end
    
    def bureau_after_stash(attachment_name)
      current = self.__send__(attachment_name)
      if !current.nil? && current[:type][/^image\//]
        convert(attachment_name, "-resize '100x75^' -gravity center -extent 100x75", 'stash_thumb.gif')
        convert(attachment_name, "-resize '184x138^' -gravity center -extent 184x138", 'nutshell.jpg')
        yield if block_given? # Block is for images transformation so that verification are processed only once
      end
    end
    
  end
  
end
