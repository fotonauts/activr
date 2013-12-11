#
# Include that module to your model to generate helper methods: `#activities` and `#activities_count`
#
# @example Model:
#   class User
#
#     # inject sugar methods
#     include Activr::Entity::ModelMixin
#
#     include Mongoid::Document
#
#     field :_id, :type => String
#     field :first_name, :type => String
#     field :last_name, :type => String
#
#     def fullname
#       "#{self.first_name} #{self.last_name}"
#     end
#
#   end
#
# @example Usage:
#   user = User.find('john')
#
#   puts "#{user.fullname} have #{user.activities_count} activites. Here are the 10 most recent:"
#
#   user.activities(10).each do |activity|
#     puts activity.humanize
#   end
#
module Activr::Entity::ModelMixin

  extend ActiveSupport::Concern

  included do
    # Entity name to use in activity feed queries
    class_attribute :activr_feed_entity_name, :instance_writer => false
    self.activr_feed_entity_name = nil
  end

  module ClassMethods

    #
    # Class interface
    #

    # Set a custom entity name to use in activity feed queries
    #
    # @param name [String] Entity name
    def activr_feed_entity(name)
      self.activr_feed_entity_name = name.to_sym
    end

  end # module ClassMethods

  # Get entity name to use for activity feed queries
  #
  # @api private
  #
  # @return [Symbol]
  def activr_feed_entity
    self.activr_feed_entity_name || Activr::Utils.kind_for_class(self.class).to_sym
  end

  # Fetch activities
  #
  # @param limit [Integer] Max number of activities to fetch
  # @param skip  [Integer] Number of activities to skip
  # @return [Array<Activr::Activity>] A list of activities
  def activities(limit, skip = 0)
    Activr.activities(limit, :skip => skip, self.activr_feed_entity => self.id)
  end

  # Get total number of activities
  #
  # @return [Integer] The total number of activities
  def activities_count
    Activr.activities_count(self.activr_feed_entity => self.id)
  end

end # module Activr::Entity::ModelMixin
