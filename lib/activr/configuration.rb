module Activr
  module Configuration

    extend ActiveSupport::Concern

    include ActiveSupport::Configurable

    included do
      # default config
      config.async    = false
      config.app_path = Dir.pwd
      config.mongodb  = {
        :uri        => 'mongodb://127.0.0.1/activr',
        :collection => 'activities',
      }

      # compiles reader methods so we don't have to go through method_missing
      config.compile_methods!

      # fetch config from fwissr
      config.async    = Fwissr['/activr/async']    unless Fwissr['/activr/async'].nil?
      config.app_path = Fwissr['/activr/app_path'] unless Fwissr['/activr/app_path'].blank?
      config.mongodb.merge!(Fwissr['/activr/mongodb'].symbolize_keys) unless Fwissr['/activr/mongodb'].blank?
    end

  end # module Configuration
end # module Activr
