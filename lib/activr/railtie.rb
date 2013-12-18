module Activr

  # Hook into Rails
  class Railtie < ::Rails::Railtie
    initializer "activr.set_conf", :after => 'mongoid.load-config' do |app|
      Activr.configure do |config|
        config.app_path = File.join(::Rails.root, 'app')

        if Fwissr['/activr/mongodb/uri'].blank? && defined?(Mongoid)
          if Mongoid::VERSION.start_with?("2.")
            # Mongoid 2
            config.mongodb[:uri] = "mongodb://#{Mongoid.master.connection.host}:#{Mongoid.master.connection.port}/#{Mongoid.master.name}"
          elsif Mongoid.sessions[:default] && !Mongoid.sessions[:default][:uri].blank?
            # Mongoid >= 3 with :uri setting
            config.mongodb[:uri] = Mongoid.sessions[:default][:uri].dup
          elsif Mongoid.sessions[:default] && !Mongoid.sessions[:default][:database].blank? && !Mongoid.sessions[:default][:hosts].blank?
            # Mongoid >= 3 without :uri setting
            config.mongodb[:uri] = "mongodb://#{Mongoid.sessions[:default][:hosts].first}/#{Mongoid.sessions[:default][:database]}"
          end
        end
      end
    end

    initializer "activr.setup_async_hooks" do |app|
      if defined?(::Resque) && (ENV['ACTIVR_FORCE_SYNC'] != 'true')
        Activr.configure do |config|
          config.async[:route_activity]  ||= Activr::Async::Resque::RouteActivity
          config.async[:timeline_handle] ||= Activr::Async::Resque::TimelineHandle
        end
      end
    end

    initializer "activr.setup_action_controller" do |app|
      ActiveSupport.on_load :action_controller do
        self.class_eval do
          before_filter do |controller|
            Activr::RailsCtx.clear_view_context!
            Activr::RailsCtx.controller = controller
          end
        end
      end
    end

    rake_tasks do
      load "activr/railties/activr.rake"
    end

    config.after_initialize do |app|
      app.config.paths.add('app/activities', :eager_load => true)
      app.config.paths.add('app/timelines',  :eager_load => true)

      Activr.setup
    end
  end # class Railtie

end # module Activr
