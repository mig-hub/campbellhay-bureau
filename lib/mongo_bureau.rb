begin
  require 'mongo_mutation'
  require 'mongo_crushyform'
  require 'mongo_stash'
rescue LoadError
  nil
end
require 'bureau/adapter'

module BackendApiAdapter
  module ClassMethods
	  def backend_get(id); id=='unique' ? find_one : get(id); end
		def backend_post(doc=nil); inst = new(doc); inst.is_new = true; inst; end
	end
	module InstanceMethods
		def backend_delete; delete; end
		def backend_put(fields); update_doc(fields); end
		def backend_values; @doc; end
		def backend_save?; !save.nil?; end
	  def backend_form(url, cols=nil, opts={})
      cols ||= default_backend_columns
      if block_given?
        fields_list = ''
        yield(fields_list)
      else
        fields_list = respond_to?(:crushyform) ? crushyform(cols) : backend_fields(cols)
      end
      o = "<form action='#{url}' method='POST' #{"enctype='multipart/form-data'" if fields_list.match(/type='file'/)} class='backend-form'>\n"
      o << backend_form_title unless block_given?
      o << fields_list
      opts[:method] = 'PUT' if (opts[:method].nil? && !self.new?)
      o << "<input type='hidden' name='_method' value='#{opts[:method]}' />\n" unless opts[:method].nil?
      o << "<input type='hidden' name='_destination' value='#{opts[:destination]}' />\n" unless opts[:destination].nil?
      o << "<input type='hidden' name='_submit_text' value='#{opts[:submit_text]}' />\n" unless opts[:submit_text].nil?
      o << "<input type='hidden' name='_no_wrap' value='#{opts[:no_wrap]}' />\n" unless opts[:no_wrap].nil?
      cols.each do |c|
        o << "<input type='hidden' name='fields[]' value='#{c}' />\n"
      end
      o << "<input type='submit' name='save' value='#{opts[:submit_text] || 'SAVE'}' />\n"
      o << "</form>\n"
      o
    end
	  def backend_delete_form(url, opts={}); backend_form(url, [], {:submit_text=>'X', :method=>'DELETE'}.update(opts)){}; end
	  def backend_clone_form(url, opts={})
      backend_form(url, [], {:submit_text=>'CLONE', :method=>'POST'}.update(opts)) do |out|
        out << "<input type='hidden' name='clone_id' value='#{self.id}' />\n"
      end
    end
    # Silly but usable form prototype
    # Not really meant to be used in a real case
    # It uses a textarea for everything
    # Override it
    # Or even better, use Sequel-Crushyform plugin instead
    def backend_fields(cols)
      o = ''
      cols.each do |c|
        identifier = "#{id}-#{self.class}-#{c}"
        o << "<label for='#{identifier}'>#{c.to_s.capitalize}</label><br />\n"
        o << "<textarea id='#{identifier}' name='model[#{c}]'>#{self[c]}</textarea><br />\n"
      end
      o
    end
		def backend_form_title; self.new? ? "<h2><span>New #{model.human_name}</span></h2>\n" : "<h2><span>Edit #{self.to_label}</span></h2>\n"; end
		def backend_show; 'OK'; end
	end
end

module MongoBureau
  
	BUREAU_CRUSHYFORM_TYPES = {
	}
  
	def self.included(base)
	  base.extend(BackendApiAdapter::ClassMethods)
		base.extend(MongoCrushyform::ClassMethods) if defined?(MongoCrushyform)
		base.extend(Bureau::Adapter::ClassMethods)
		base.extend(ClassMethods)
		base.bureau_config = {:nut_tree_class=>'sortable-grid'}
		base.crushyform_types.update(BUREAU_CRUSHYFORM_TYPES)
	end

  module ClassMethods
    attr_accessor :list_options
    
	  def list_view(r)
		  @list_options = {:request=>r, :destination=>r.fullpath, :path=>r.script_name, :filter=>r['filter'] }
			@list_options.store(:sortable,sortable_on_that_page?)
		  out = list_view_header
		  out << scene_selector unless bureau_config[:scene_selector_class].nil?
			out << many_to_many_picker unless bureau_config[:minilist_class].nil?
			out << "<ul class='nut-tree #{'sortable' if @list_options[:sortable]} #{bureau_config[:nut_tree_class]}' id='#{self.name}' rel='#{@list_options[:path]}/#{self.name}'>"
			self.find(typecast_filter(@list_options[:filter]||{}), (self.respond_to?(:list_view_fields) ? {fields: self.list_view_fields} : {})).each do |m| 
        out << m.to_nutshell
      end
			out << "</ul>"
		end
		
		def sortable_on_that_page?
      o = @list_options
      o[:search].nil? && @schema.key?('position') && (@schema['position'][:scope].nil? || (o[:filter]||{}).key?(@schema['position'][:scope]))
    end
    
    def minilist_view
      o = "<ul class='minilist'>\n"
      self.find.each do |m|
        thumb = m.respond_to?(:to_bureau_thumb) ? m.to_bureau_thumb('stash_thumb_gif') : m.placeholder_thumb('stash_thumb_gif')
        o << "<li title='#{m.to_label}' id='mini-#{m.id}'>#{thumb}<div>#{m.to_label}</div></li>\n"
      end
      o << "</ul>\n"
    end
    
    def scene_selector
      o = @list_options
      klass = bureau_config[:scene_selector_class].is_a?(Symbol) ? Kernel.const_get(bureau_config[:scene_selector_class]) : bureau_config[:scene_selector_class]
      obj = klass.get(o[:filter]["id_#{bureau_config[:scene_selector_class]}"])
      unless obj.nil?
        out = "<p>Point and click in order to highlight a zone.</p>\n"
        out << obj.build_image_tag('image','original', :class=>'mapolygon-me')
        save_btn = command_plus.sub(/btn btn-plus/, 'save-mapolygon').sub(/></, '>Create this zone<').sub(/(href='[^']*)/, "\\1&model[coordinates]=")
        out << "<div class='scene-selector-toolbar'><button type='button' class='reset-mapolygon'>Reset</button> #{save_btn}</div>\n"
      end
    end
    
    private
    
    def image_slot(name='image',opts={})
		  super(name,opts)
			# First image slot is considered the best bureau thumb
			unless instance_methods.include?(:to_bureau_thumb)
			  define_method :to_bureau_thumb do |style|
				  generic_thumb(name, style)
				end
			end
		end

    def typecast_filter filter={}
      filter.each do |k,v|
        filter[k] = true if v=='true'
        filter[k] = false if v=='false'
        filter[k] = v.to_i if v[/^\d+$/]
      end
    end

	end

  include BackendApiAdapter::InstanceMethods
	include MongoCrushyform::InstanceMethods if defined?(MongoCrushyform)
	include Bureau::Adapter::InstanceMethods

	def after_stash(col)
	  convert(col, "-resize '100x75^' -gravity center -extent 100x75", 'stash_thumb_gif')
		convert(col, "-resize '184x138^' -gravity center -extent 184x138", 'nutshell_jpg')
	end

  def bureau_attachment_url_for obj, col='image', size='original'
    return obj.attachment_url(col,size) if obj.respond_to?(:attachment_url)
    "/gridfs/#{obj.doc[col][size]}"
  end

  def generic_thumb(img , size='stash_thumb_gif', obj=self)
    return placeholder_thumb(size) if obj.nil?
	  current = obj.doc[img]
		if !current.nil? && !current[size].nil?
		  "<img src='#{bureau_attachment_url_for(obj,img,size)}' onerror=\"this.style.display='none'\" />\n"
		else
		  placeholder_thumb(size)
		end
	end
	
  def to_thumb(c)
    current = @doc[c]
    if current.respond_to?(:[])
      img_url = @doc[c]['stash_thumb_gif'].nil? ? model.list_options&&"#{model.list_options[:path]}/_static/img/file.png" : bureau_attachment_url_for(self,c,'stash_thumb_gif')
      "<img src='#{img_url}' #{"width='100'" unless @doc[c]['stash_thumb_gif'].nil?} onerror=\"this.style.display='none'\" />\n"
    end
  end
  
  def scene_selector_coordinates; @doc['coordinates']; end

	def in_nutshell
    o = model.list_options
		out = "<div class='in-nutshell'>\n"
		out << self.to_bureau_thumb('nutshell_jpg') if self.respond_to?(:to_bureau_thumb)
		cols = model.bureau_config[:quick_update_fields] || nutshell_backend_columns.select{|col| 
		  [:boolean,:select].include?(model.schema[col][:type]) && !model.schema[col][:multiple] && !model.schema[col][:no_quick_update]
		}
		cols.each do |c|
		  column_label = model.schema[c][:name] || c.to_s.sub(/^id_/, '').tr('_', ' ').capitalize
		  out << "<div class='quick-update'><form><span class='column-title'>#{column_label}:</span> #{self.crushyinput(c)}</form></div>\n"
	  end
		out << "</div>\n"
  end

	def nutshell_children
		o = model.list_options
		out = ""
		nutshell_backend_associations.each do |k, opts|
		  next if opts[:hidden]
		  k = Kernel.const_get(k)
			link = "#{o[:path]}/list/#{k}?filter[#{model.foreign_key_name}]=#{self.id}"
			text = opts[:link_text] || "#{k.human_name}(s)"
			out << "<a href='#{link}' class='push-stack sublist-link nutshell-child'>#{text} #{self.children_count(k) unless opts[:hide_count]}</a>\n"
		end
		out
	end
    
	def nutshell_backend_associations
	  model.relationships
	end

  def default_backend_columns; model.schema.keys; end
	def cloning_backend_columns; default_backend_columns.reject{|c| model.schema[c][:type]==:attachment}; end

end
