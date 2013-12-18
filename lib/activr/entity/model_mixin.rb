#
# Including that module in your model class adds these methods: {#activities}, {#activities_count} and
# {#delete_activities!}.
#
# If you plan to call either {#activities} or {#activities_count} methods then set the `:feed_index => true`
# entity setting to ensure that an index is correctly setup when running the `rake activr:create_indexes` task.
#
# If you plan to call {#delete_activities!} method then you should set the `:deletable => true` entity setting
# to ensure that a deletion index is correctly setup when running the `rake activr:create_indexes` task.
#
# @example Model:
#   class User
#
#     # inject sugar methods
#     include Activr::Entity::ModelMixin
#
#     activr_entity :feed_index => true, :deletable => true
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
#     after_destroy :delete_activities!
#
#   end
#
# @example Usage:
#   user = User.find('john')
#
#   puts "#{user.fullname} has #{user.activities_count} activites. Here are the 10 most recent:"
#
#   user.activities(10).each do |activity|
#     puts activity.humanize
#   end
#
module Activr::Entity::ModelMixin

  extend ActiveSupport::Concern

  included do
    # Entity settings
    class_attribute :activr_entity_settings, :instance_writer => false
    self.activr_entity_settings = { :feed_index => false, :deletable => false, :name => nil }

    # Register model
    Activr.registry.add_model(self)
  end

  # Class methods for the {ModelMixin} mixin
  module ClassMethods

    # Get entity name to use for activity feed queries
    #
    # @api private
    #
    # @return [Symbol]
    def activr_entity_feed_actual_name
      self.activr_entity_settings[:name] || Activr::Utils.kind_for_class(self).to_sym
    end


    #
    # Class interface
    #

    # Set a custom entity name to use in entity activity feed queries
    #
    # @note By default, the entity name is inferred from the model class name
    # @todo Add documentation in README for that
    #
    # @param settings [Hash] Entity settings
    # @option settings [Boolean] :deletable  Entity is deletable ? (default: `false`)
    # @option settings [String]  :name       Custom entity name to use in entity activity feed queries (default is inferred from model class name)
    # @option settings [Boolean] :feed_index Ensure entity activity feed index ? (default: `false`)
    def activr_entity(settings)
      self.activr_entity_settings = self.activr_entity_settings.merge(settings)
    end

  end # module ClassMethods

  # sugar
  def activr_entity_feed_actual_name
    self.class.activr_entity_feed_actual_name
  end

  # Fetch activities
  #
  # @param limit [Integer] Max number of activities to fetch
  # @param skip  [Integer] Number of activities to skip
  # @return [Array<Activity>] A list of activities
  def activities(limit, skip = 0)
    Activr.activities(limit, :skip => skip, self.activr_entity_feed_actual_name => self.id)
  end

  # Get total number of activities
  #
  # @return [Integer] The total number of activities
  def activities_count
    Activr.activities_count(self.activr_entity_feed_actual_name => self.id)
  end

  # Delete all activities and timeline entries that reference that entity
  def delete_activities!
    # delete activities
    Activr.storage.delete_activities_for_entity_model(self)

    # delete timeline entries
    Activr.storage.delete_timeline_entries_for_entity_model(self)
  end

end # module Activr::Entity::ModelMixin
