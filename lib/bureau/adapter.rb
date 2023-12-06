module Bureau
  module Adapter
  
    module ClassMethods
      attr_accessor :bureau_config, :list_options
    
      def list_view(r)
        "Override Me -- #{self.name}#list_view"
      end

      def foreign_key_name(plural=false); "id#{'s' if plural}_"+self.name; end
      def human_name; self.name.gsub(/([A-Z])/, ' \1')[1..-1]; end
      def human_plural_name; human_name+'s'; end
      def list_title; human_plural_name; end

      def list_view_header
        o = @list_options
        out = "<h2 class='list-title slide-title'><span>#{list_title}</span><div class='nut-tree-toolbar'>"
        out << command_plus unless bureau_config[:no_plus]
        out << command_reload
        out << command_search unless bureau_config[:no_search]
        out << "</div></h2>\n"
      end

      def sortable_on_that_page?
        false
      end

      def command_reload
        "<a class='btn btn-reload' href='#' title='Reload'></a>\n"
      end

      def command_plus
        o = @list_options
        path = "#{o[:path]}/#{self.name}?_no_wrap=true&_destination=#{::Rack::Utils::escape(o[:destination])}"
        o[:filter].each{|k,v|path<<"&model[#{k}]=#{::Rack::Utils::escape(v)}"} unless o[:filter].nil?
        "<a href='#{path}' class='btn btn-plus push-stack' title='Create'></a>\n"
      end

      def command_search
        o = @list_options
        "<form action='#{o[:destination]}' method='GET' class='search'>Search:<input type='search' name='q' value='#{o[:request]['q']}' /><input type='submit' value='Search' /></form>"
      end

      def many_to_many_picker
        opts = @list_options
        klass = bureau_config[:minilist_class].is_a?(Symbol) ? Kernel.const_get(bureau_config[:minilist_class]) : bureau_config[:minilist_class]
        klass.list_options = @list_options
        params_sample = (opts[:filter]||{}).map{|k,v| "model[#{k}]=#{::Rack::Utils::escape(v)}" }
        params_sample << "model[#{klass.foreign_key_name}]="
        o = "<div class='many-to-many-picker' rel='#{params_sample.join('&')}'>\n"
        o << "<div class='many-to-many-search'>Filter:<input type='search' class='minisearch' name='minisearch' /> Drag and Drop what you want to add</div>\n"
        o << "<div class='minilist-wrapper'>\n"
        o << klass.minilist_view
        o << "</div>\n"
        o << "</div>\n"
      end
    
    end
  
    module InstanceMethods
    
      def nutshell_header
        o = model.list_options
        out = "<div class='nutshell-header'><div class='nutshell-title' title='#{self.to_label}'>#{self.to_label}</div>"
        out << "<div class='sortable-handle btn' title='Drag Me'></div>\n" if o[:sortable]
        out << "</div>\n"
      end
      def in_nutshell
        o = model.list_options
  			out = "<div class='in-nutshell'>\n"
  			out << self.to_bureau_thumb('nutshell.jpg') if self.respond_to?(:to_bureau_thumb)
  			out << "</div>\n"
      end
      def nutshell_toolbar
        o = model.list_options
        class_path = "#{o[:path]}/#{model.name}"
        path = "#{class_path}/#{self.id}"
        out = "<div class='nutshell-toolbar'>Tools:"
        out << "#{self.backend_delete_form(path, :destination=>o[:destination])}<div class='btn btn-delete' title='Delete'></div>\n" unless model.bureau_config[:no_delete]
        out << "#{self.backend_clone_form(class_path, :destination=>o[:destination])}<div class='btn btn-clone' title='Clone'></div>\n" unless (model.bureau_config[:no_plus]||model.bureau_config[:no_clone])
        out << "<a href='#{preview_on_frontend}#{preview_on_frontend.match(/\?/) ? '&' : '?'}_preview=true' class='btn btn-preview' target='_blank' title='Preview'></a>\n" unless preview_on_frontend.nil?
        out << "<a href='#{path}?_no_wrap=true&_destination=#{::Rack::Utils::escape(o[:destination])}' class='btn btn-edit push-stack' title='Edit'></a>\n" unless model.bureau_config[:no_edit]
        out << "</div>\n"
      end
      def nutshell_children; ''; end
    
      def to_nutshell
        out = "<li class='nutshell nutshell-#{model.name}' id='#{model.name}-#{self.id}' data-scene-selector-coordinates='#{self.scene_selector_coordinates if self.respond_to?(:scene_selector_coordinates)}'>"
        out << nutshell_header
        out << in_nutshell
        out << nutshell_toolbar
        out << nutshell_children
        out << "</li>"
      end
     
      def placeholder_thumb(size)
        o = model.list_options
        "<img src='#{o[:path]}/_static/img/placeholder.#{size.gsub(/^(.*)_([a-zA-Z]+)$/, '\1.\2')}' />\n"
      end
    
      # Override the clone column list from RackBackendAPI
      def cloning_backend_columns
        model.respond_to?(:stash) ? (default_backend_columns - model.stash_reflection.keys) : default_backend_columns
      end
  		# Default list of columns for nutshell
  		def nutshell_backend_columns; default_backend_columns; end
      # Meant to be ovveridden with a link to see the entry in the frontend if applicable
      def preview_on_frontend; nil; end
    
    end

  end
end
