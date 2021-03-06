module Activr

  #
  # That module gives configuration behaviour to includer
  #
  # @see ActiveSupport::Configurable
  #
  module Configuration

    extend ActiveSupport::Concern

    include ActiveSupport::Configurable

    included do
      # default config
      config.app_path = Dir.pwd
      config.skip_dup_period = nil

      config.mongodb = {
        :uri            => 'mongodb://127.0.0.1/activr',
        :col_prefix     => nil,
        :activities_col => nil,
        :timelines_col  => nil,
      }

      config.async = { }

      # compiles reader methods so we don't have to go through method_missing
      config.compile_methods!

      # fetch config from fwissr
      config.app_path        = Fwissr['/activr/app_path']             unless Fwissr['/activr/app_path'].blank?
      config.skip_dup_period = Fwissr['/activr/skip_dup_period']      unless Fwissr['/activr/skip_dup_period'].blank?
      config.mongodb.merge!(Fwissr['/activr/mongodb'].symbolize_keys) unless Fwissr['/activr/mongodb'].blank?
      config.async.merge!(Fwissr['/activr/async'].symbolize_keys)     unless Fwissr['/activr/async'].blank?
    end

  end # module Configuration

end # module Activr
