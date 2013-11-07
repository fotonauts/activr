module Activr
  class Railtie < Rails::Railtie

    initializer "activr.configure_rails_initialization" do
      Activr.config.app_path = File.join(Rails.root, 'app')

      config.autoload_paths << File.join(Activr.config.app_path, 'activities')
      config.autoload_paths << File.join(Activr.config.app_path, 'timelines')
    end

  end
end
