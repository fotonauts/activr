module Activr

  class Timeline

    autoload :Entry, 'activr/timeline/entry'
    autoload :Route, 'activr/timeline/route'

    # routings
    class_attribute :routings
    self.routings = { }

    # routes (ordered by priority)
    class_attribute :routes
    self.routes = [ ]


    class << self

      # check if given route was already defined
      def have_route?(route_to_check)
        !self.routes.find do |defined_route|
          (defined_route.kind == route_to_check.kind)
        end.nil?
      end


      #
      # Class interface
      #

      # define a routing
      def routing(routing_name, settings = { }, &block)
        raise "Routing already defined" unless self.routings[routing_name].blank?

        if block
          raise "Forbidden to provide a block AND a :to setting" if settings[:to]
          settings = settings.merge(:to => block)
        end

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.routings = self.routings.merge(routing_name => settings)
      end

      # define a route for an activity
      def route(activity_class, settings = { })
        new_route = Activr::Timeline::Route.new(activity_class, settings)
        raise "Route already defined: #{new_route.inspect}" if self.have_route?(new_route)

        # NOTE: always use a setter on a class_attribute (cf. http://apidock.com/rails/Class/class_attribute)
        self.routes += [ new_route ]

        # register used timeline
        Activr.registry.add_timeline(self)
      end

    end # class << self

  end # class Timeline

end # module Activr
