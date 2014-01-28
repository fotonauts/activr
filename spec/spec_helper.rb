require 'rubygems'

require 'mongoid'
require 'rspec'
require 'database_cleaner'
require 'delorean'

require 'coveralls'
Coveralls.wear!

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'activr'

def rspec_mongo_host
  Fwissr['/activr/rspec_mongo_host'] || "127.0.0.1"
end

def rspec_mongo_port
  Fwissr['/activr/rspec_mongo_port'] || 27017
end

def rspec_mongo_db
  Fwissr['/activr/rspec_mongo_db'] || "activr_spec"
end


Activr.configure do |config|
  config.app_path      = File.join(File.dirname(__FILE__), "app")
  config.mongodb[:uri] = "mongodb://#{rspec_mongo_host}:#{rspec_mongo_port}/#{rspec_mongo_db}"
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
  if config.respond_to?(:sessions)
    if Mongoid::VERSION.start_with?("3.")
      # mongoid 3
      config.sessions = {
        default: {
          database: rspec_mongo_db,
          hosts: [ "#{rspec_mongo_host}:#{rspec_mongo_port}" ],
          options: { read: :primary, safe: true }
        }
      }
    else
      # mongoid 4
      config.sessions = {
        default: {
          database: rspec_mongo_db,
          hosts: [ "#{rspec_mongo_host}:#{rspec_mongo_port}" ],
          options: { read: :primary }
        }
      }
    end
  else
    # mongoid 2
    config.master = Mongo::Connection.new(rspec_mongo_host, rspec_mongo_port).db(rspec_mongo_db)
  end
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
