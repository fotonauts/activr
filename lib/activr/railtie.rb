module Activr

  class Railtie < Rails::Railtie
    initializer "activr.configure_rails_initialization", :before => :set_autoload_paths do |app|
      Activr.config.app_path = File.join(Rails.root, 'app')

      app.config.autoload_paths << File.join(Activr.config.app_path, 'activities')
      app.config.autoload_paths << File.join(Activr.config.app_path, 'timelines')
    end
  end

end
