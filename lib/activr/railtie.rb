module Activr

  class Railtie < Rails::Railtie
    initializer "activr.set_conf", :after => 'mongoid.load-config' do |app|
      Activr.configure do |config|
        config.app_path = File.join(Rails.root, 'app')
        # @todo Remove that when async workers system is ready
        config.sync = true

        if Mongoid.sessions[:default] && !Mongoid.sessions[:default][:database].blank? && !Mongoid.sessions[:default][:hosts].blank?
          config.mongodb[:uri] = "mongodb://#{Mongoid.sessions[:default][:hosts].first}/#{Mongoid.sessions[:default][:database]}"
        end
      end
    end

    config.after_initialize do |app|
      app.config.paths.add('app/activities', :eager_load => true)
      app.config.paths.add('app/timelines',  :eager_load => true)
    end

    config.after_initialize do
      Activr.setup
    end
  end

end
