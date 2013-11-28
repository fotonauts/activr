require 'rubygems'
require 'mongoid'
require 'rspec'
require 'database_cleaner'

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'activr'

def tmp_mongo_db
  "activr_spec"
end


Activr.configure do |config|
  config.sync          = true
  config.app_path      = File.join(File.dirname(__FILE__), "app")
  config.mongodb[:uri] = "mongodb://127.0.0.1/#{tmp_mongo_db}"
end

MODELS_PATH = File.join(Activr.config.app_path, "models")
$:.unshift(MODELS_PATH)

ACTIVITIES_PATH = File.join(Activr.config.app_path, "activities")
$:.unshift(ACTIVITIES_PATH)

TIMELINES_PATH = File.join(Activr.config.app_path, "timelines")
$:.unshift(TIMELINES_PATH)

# autoload classes
[ MODELS_PATH, ACTIVITIES_PATH, TIMELINES_PATH ].each do |dir_path|
  Dir[ File.join(dir_path, "*.rb") ].sort.each do |file_path|
    name = File.basename(file_path, ".rb")
    autoload(name.camelize.to_sym, name)
  end
end

# Uncomment that line if you want to see Moped log
# Moped.logger = Activr.logger if defined?(Moped)

Mongoid.configure do |config|
  config.connect_to(tmp_mongo_db)
end

RSpec.configure do |config|
  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

# setup
Activr.setup
