require 'rubygems'
require 'mongoid'
require 'rspec'
require 'database_cleaner'

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'activr'

MODELS = File.join(File.dirname(__FILE__), "app/models")
$:.unshift(MODELS)

ACTIVITIES = File.join(File.dirname(__FILE__), "app/activities")
$:.unshift(ACTIVITIES)


def tmp_mongo_db
  "activr_spec"
end

Mongoid.configure do |config|
  config.connect_to(tmp_mongo_db)
end

# autoload models
Dir[ File.join(MODELS, "*.rb") ].sort.each do |file|
  name = File.basename(file, ".rb")
  autoload(name.camelize.to_sym, name)
end

# require activities
Dir[ File.join(ACTIVITIES, "*.rb") ].each do |file|
  require File.basename(file)
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
