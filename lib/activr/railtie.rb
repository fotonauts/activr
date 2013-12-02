module Activr

  class Railtie < ::Rails::Railtie
    initializer "activr.set_conf", :after => 'mongoid.load-config' do |app|
      Activr.configure do |config|
        config.app_path = File.join(::Rails.root, 'app')

        if Mongoid.sessions[:default] && !Mongoid.sessions[:default][:database].blank? && !Mongoid.sessions[:default][:hosts].blank?
          config.mongodb[:uri] = "mongodb://#{Mongoid.sessions[:default][:hosts].first}/#{Mongoid.sessions[:default][:database]}"
        end
      end
    end

    initializer "activr.setup_async_hooks" do |app|
      if defined?(::Resque)
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
            Activr::Rails.clear_view_context!
            Activr::Rails.controller = controller
          end
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
