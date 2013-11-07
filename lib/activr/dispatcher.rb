module Activr
  class Dispatcher

    class << self

      # @todo !!!

    end # class << self

    # init
    def initialize
      # @todo !!!
    end

    # route an activity
    #
    # @param activity [Activr::Activity] Activity instance to route
    def route(activity)
      raise "Activity must be stored before routing: #{activity.inspect}" if activity._id.nil?

      # @todo !!!
      raise "not implemented"
    end

  end # class Dispatcher
end # module Activr
