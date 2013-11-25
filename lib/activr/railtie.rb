module Activr

  class Railtie < Rails::Railtie
    initializer "activr.configure_autoload", :before => :set_autoload_paths do |app|
      Activr.config.app_path = File.join(Rails.root, 'app')

      app.config.autoload_paths << File.join(Activr.config.app_path, 'activities')
      app.config.autoload_paths << File.join(Activr.config.app_path, 'timelines')
    end

    initializer "activr.set_conf", :after => 'mongoid.load-config' do |app|
      Activr.configure do |config|
        # @todo Remove that when async workers system is ready
        config.sync = true

        if Mongoid.sessions[:default] && !Mongoid.sessions[:default][:database].blank? && !Mongoid.sessions[:default][:hosts].blank?
          config.mongodb[:uri] = "mongodb://#{Mongoid.sessions[:default][:hosts].first}/#{Mongoid.sessions[:default][:database]}"
        end
      end
    end
  end

end
