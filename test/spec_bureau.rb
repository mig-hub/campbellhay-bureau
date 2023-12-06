require 'rubygems'
require 'bacon'
require 'rack'
require 'fileutils' # fix Rack missing

Bacon.summary_on_exit

# Helpers
F = ::File
D = ::Dir
ROOT = F.dirname(__FILE__)+'/..'
$:.unshift ROOT+'/lib'
require 'bureau'

# =========
# = Basic =
# =========

class Basic
  include Bureau
  config.update :client_name=>"me", :index => ['my_index','with','args']
  
  before do
    bureau_before
    if @action=='instance_config' && !@action_arguments.empty?
      _config.update :client_name=>@action_arguments.join(' ')
      @action_arguments = []
    end
    if @action=='wrapped' && @r['with_head_addons']=='true'
      _config[:head_addons] = "<!-- ADDONS -->"
    end
  end
  
  def client_name; self.class.config[:client_name]; end
  def instance_config; _config[:client_name]; end
  def get_cms_path; _config[:path]; end
  def wrapped; @content = ''; _with_layout; end
  def is_it_xhr; xhr?.to_s; end
  def my_index(*a); a.join('+'); end
  def nude_index; 'nude'; end
end
R = ::Rack::MockRequest.new(::Rack::Lint.new(Basic.new))
wrapR = ::Rack::MockRequest.new(::Rack::Lint.new(Basic.new(proc{|env|
  ::Rack::Response.new("<!-- #{::Rack::Utils::unescape(::Rack::Request.new(env)['_destination'])} -->", 201, {'Content-Type'=>'text/html'
}).finish})))

# =========
# = Specs =
# =========

describe 'Bureau Static Files' do
  
  it "Should include Golem mini framework" do
    Basic.ancestors.include?(Rack::Golem).should==true
  end
  
  it "Has a static file path" do
    R.get('/_static/_test.txt').body.should=='works'
  end
  
  it "Reads templates" do
    Basic.read('_test.txt').should=='works'
  end
  
end

describe 'Bureau Config' do
  
  it "Should have the right :cms_path automatically after first use of _config" do
    Basic.config[:path].should=='/admin'
    R.get('/get_cms_path').body.should==''
    Basic.config[:path].should==''
  end
  
  it "Should be possible to change config values" do
    R.get('/client_name').body.should=='me'
  end
  
  it "Can override instance config for each request" do
    R.get('/instance_config').body.should=='me'
    R.get('/instance_config/has/changed').body.should=='has changed'
    Basic.config[:client_name].should=='me'
    R.get('/instance_config').body.should=='me'
  end
  
  it "Can build the menu" do
    b = R.get('/wrapped').body
    b.should.match(/<div class='menu-section-title'>Menu<\/div>/)
    b.should.match(/<a class='' href='\/'>Home<\/a><br \/>/)
  end
  
  it "Can add things at the end of <head> through _config" do
    R.get('/wrapped?with_head_addons=true').body.should.match(/<!-- ADDONS -->\n<\/head>/)
    R.get('/wrapped').body.should.not.match(/<!-- ADDONS --><\/head>/)
  end
  
end

describe "Bureau Helpers" do
  
  it "Should have a xhr? helper that detects pseudo xhr" do
    R.get('/is_it_xhr').body.should=='false'
    R.get('/is_it_xhr', "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest").body.should=='true'
    R.get('/is_it_xhr?_xhr=true').body.should=='true'
  end
  
end

describe "Bureau behaviour" do
  
  it "Can wrap form sent by BackendAPI and set _destination" do
    res = wrapR.get('/Model/3?_no_wrap=true')
    res.status.should==201
    res.body.should.match(/^<!DOCTYPE html>.*<!-- \/Model\/3\?_no_wrap=true -->.*<\/html>$/m)
  end
  
  it "Can have an index" do
    R.get('/').body.should=='with+args'
    Basic.config.update({:index=>['nude_index']})
    R.get('/').body.should=='nude'
  end
  
end