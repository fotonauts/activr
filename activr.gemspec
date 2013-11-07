require File.join(File.dirname(__FILE__), 'lib', 'activr', 'version')

spec = Gem::Specification.new do |s|
  s.name        = "activr"
  s.version     = Activr::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Activr"
  s.description = <<-EOF
  Activity Streams system by Fotonauts.
  EOF

  s.author   = "Aymerick JEHANNE"
  s.homepage = "https://github.com/fotonauts/activr"
  s.email    = [ "aymerick@fotonauts.com" ]

  s.require_paths = [ "lib" ]
  s.files         = %w( LICENSE Rakefile README.md ) + Dir["{lib}/**/*"]

  s.add_dependency("mustache")
  s.add_dependency("mongo")
  s.add_dependency("bson_ext")
  s.add_dependency("fwissr")
  s.add_dependency("activesupport")

  s.add_development_dependency("rspec")
  s.add_development_dependency("mongoid", "~> 2.8")
  s.add_development_dependency("database_cleaner")
end
