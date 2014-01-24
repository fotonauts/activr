class User

  include Activr::Entity::ModelMixin

  activr_entity :feed_index => true

  include Mongoid::Document

  field :_id, :type => String

  field :first_name
  field :last_name

  field :nil_field

  # needed for mongoid 3
  if self.respond_to?(:attr_accessible)
    attr_accessible :id, :_id, :first_name, :last_name, :nil_field
  end

  attr_accessor :followers


  def fullname
    "#{self.first_name} #{self.last_name}"
  end

  # I know this is bad, this is just for testing purpose
  def to_html
    "<span class='user'>#{fullname}<span>"
  end

end
