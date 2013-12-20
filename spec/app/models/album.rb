class Album

  include Activr::Entity::ModelMixin

  activr_entity :feed_index => true, :deletable => true

  include Mongoid::Document

  field :name

  # needed for mongoid 3
  if self.respond_to?(:attr_accessible)
    attr_accessible :id, :_id, :name
  end

  # @todo change to real fields
  attr_accessor :owner
  attr_accessor :followers

  # callbacks
  after_destroy :delete_activities!


  # used by Activr::Entity to humanize entity
  def humanize(options)
    if options[:html]
      "<span class='album'>#{self.name}</span>"
    else
      self.name
    end
  end

end
