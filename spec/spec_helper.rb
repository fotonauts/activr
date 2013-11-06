require 'rubygems'
require 'mongoid'
require 'rspec'
require 'database_cleaner'


$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'activr'

Activr.app_path = File.join(File.dirname(__FILE__), "app")

MODELS_PATH = File.join(Activr.app_path, "models")
$:.unshift(MODELS_PATH)

ACTIVITIES_PATH = File.join(Activr.app_path, "activities")
$:.unshift(ACTIVITIES_PATH)

TIMELINES_PATH = File.join(Activr.app_path, "timelines")
$:.unshift(TIMELINES_PATH)

# autoload classes
[ MODELS_PATH, ACTIVITIES_PATH, TIMELINES_PATH ].each do |dir_path|
  Dir[ File.join(dir_path, "*.rb") ].sort.each do |file_path|
    name = File.basename(file_path, ".rb")
    autoload(name.camelize.to_sym, name)
  end
end

def tmp_mongo_db
  "activr_spec"
end

Mongoid.configure do |config|
  config.connect_to(tmp_mongo_db)
end

RSpec.configure do |config|
  config.before(:each) do
    DatabaseCleaner.start
    Mongoid::IdentityMap.clear
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
