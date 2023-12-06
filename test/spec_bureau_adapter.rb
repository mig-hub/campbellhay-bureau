require 'rubygems'
require 'bacon'
Bacon.summary_on_exit

F = ::File
D = ::Dir
ROOT = F.dirname(__FILE__)+'/..'
$:.unshift(ROOT+'/lib')

require 'sequel'
DB = ::Sequel.sqlite
::Sequel::Model.plugin :schema
::Sequel::Model.plugin :crushyform

class NoSort < ::Sequel::Model
  set_schema do
    primary_key :id
    Fixnum :position
    String :category
    String :name
  end
  create_table unless table_exists?
  plugin :bureau_adapter
end

class SimpleSort < ::Sequel::Model
  set_schema do
    primary_key :id
    Fixnum :position
    String :category
    String :name
  end
  create_table unless table_exists?
  plugin :bureau_adapter
  plugin :list
end

class ScopeSort < ::Sequel::Model
  set_schema do
    primary_key :id
    Fixnum :position
    String :category
    String :name
  end
  create_table unless table_exists?
  plugin :bureau_adapter, :position_scope=>:category
  plugin :list, :scope=>:category 
end

describe "Bureau Adapter" do
  
  should "Set sortable_on_that_page? correctly" do
    # Each class with: No filter / Good filter / Good filter but not alone / Bad filter
    
    NoSort.sortable_on_that_page?.should==false
    NoSort.sortable_on_that_page?({:filter => {:category=>'4'}}).should==false
    NoSort.sortable_on_that_page?({:filter => {:category=>'4', :name=>'4'}}).should==false
    NoSort.sortable_on_that_page?({:filter => {:name=>'4'}}).should==false
    
    SimpleSort.sortable_on_that_page?.should==true
    SimpleSort.sortable_on_that_page?({:filter => {:category=>'4'}}).should==false
    SimpleSort.sortable_on_that_page?({:filter => {:category=>'4', :name=>'4'}}).should==false
    SimpleSort.sortable_on_that_page?({:filter => {:name=>'4'}}).should==false
    
    ScopeSort.sortable_on_that_page?.should==false
    ScopeSort.sortable_on_that_page?({:filter => {:category=>'4'}}).should==true
    ScopeSort.sortable_on_that_page?({:filter => {:category=>'4', :name=>'4'}}).should==false
    ScopeSort.sortable_on_that_page?({:filter => {:name=>'4'}}).should==false
  end
  
end