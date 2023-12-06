require 'rack/golem'

module Bureau
  F = ::File
  DIR = F.expand_path(F.dirname(__FILE__))
  BEFORE = Proc.new{
    if @r.fullpath.sub(/\/$/, '')==_config[:path]&&_config[:index]
      @action, *@action_arguments = _config[:index]
    end
    if @r['_no_wrap']
      @action = "wrap_api_response"
      @api_arguments = @action_arguments
      @action_arguments = []
      if @r['_destination'].nil?
        dest = "&_destination=#{::Rack::Utils::escape(@r.fullpath)}"
        @r.env.update({'QUERY_STRING'=>@r.env['QUERY_STRING']+dest})
      end
    end
  }
  
  def self.included(klass)
    klass.class_eval do
      extend ClassMethods
      include InstanceMethods
      include Rack::Golem
    end
    klass.before(&BEFORE)
  end
  
  module ClassMethods
    def new(*); ::Rack::Static.new(super, :urls => ["/_static"], :root => DIR); end 
    def read(p); F.read("%s/_templates/%s" % [DIR,p]); end
    def config
      @config ||= {
        :client_name => 'Client Name',
        :website_url => 'www.domain.com',
        :path => '/admin',
        :logout_path => '/admin/logout', # sometimes higher in stack
        :menu => [[['Home', '/']]],
        :head_addons => '',
        :index => nil
      }
    end
  end
  
  module InstanceMethods
    
    def list(m); @content = Kernel.const_get(m).list_view(@r); _finish; end
    #def edit(m,id); @content = eval(m)[id].backend_form(_config[:path]+'/'+m+'/'+id); _finish; end
    
    def submenu(group,section)
      title, *links = _config[:menu][group.to_i][section.to_i]
      @content = "<h2 class='slide-title'><span>#{title}</span></h2>"
      @content << "<ul class='submenu-list'>\n"
      until links.empty?
        @content << "<li><a class='push-stack' href='#{links.shift}'>#{links.shift}</a></li>\n"
      end
      @content << "</ul>\n"
      _finish
    end

    def help
      @content = _t('help.html')
      _finish
    end

    def wrap_api_response
      status, header, body = @app.call(@r.env)
      @res.status = status
      @res.header.replace(header)
      @content = body.inject(''){|r,s| r+s }
      _with_layout
    end
    
    private
    
    def _t(p); self.class.read(p); end # read template
    
    def _finish; xhr? ? @content : _with_layout; end
    
    def _with_layout # Take @content and wrap it in the layout
      admin = (@r.env['rack.session'] || {})['cerberus_user']
      greetings = admin.nil? ? '' : admin.tr('_-', '  ').upcase
      logout_btn = "<a class='logout' href='#{_config[:logout_path]}'>Logout</a>"
      _t('layout.html') % [_head, greetings, _menu, logout_btn, @content]
    end
    
    def _config; @cms_config ||= self.class.config.update(:path=>@r.script_name).dup; end # Instance config
    
    def _menu
      o = "<ul id='menu-list'>\n"
      _config[:menu].each_with_index do |group,group_i|
        o << "<ul class='menu-group-list'>\n"
        group.each_with_index do |section,section_i|
          title, *links = section
          selected = links.include?(@r.env['REQUEST_URI']) || @r.env['REQUEST_URI'][/\/submenu\/#{group_i}\/#{section_i}$/]
          o << "<li class='menu-section #{selected&&'selected-menu-section'||''}'>"
          url = links.size==1 ? links[0] : "#{_config[:path]}/submenu/#{group_i}/#{section_i}"
          o << "<a href='#{url}'>#{title}</a>"
          o << "</li>\n"
        end
        o << "</ul>\n"
      end
      o << "</ul>\n"
    end
    
    def _head
      p = _config[:path]
      _t('head.html') % [
        p,p,p, # CSS
        p,p,p,p,p,p,p,p,p,p,p, # JS
        _config[:head_addons]
      ]
    end
    
    def xhr?; @r.xhr?||@r['_xhr']=='true'; end
    
    def bureau_before; instance_eval(&Bureau::BEFORE); end
  
  end
  
end
