Gem::Specification.new do |s| 
  s.name = 'campbellhay-bureau'
  s.version = "4.1.7"
  s.platform = Gem::Platform::RUBY
  s.summary = "The CampbellHay Admin System"
  s.description = "The CampbellHay Admin System"
  s.files = `git ls-files`.split("\n").sort
  s.require_path = './lib'
  s.author = "Mickael Riga"
  s.email = "mig@campbellhay.com"
  s.homepage = "http://www.campbellhay.com"
  s.add_dependency('rack-golem')
end

