class Album

  include Mongoid::Document

  field :name

  # needed for mongoid 3
  if self.respond_to?(:attr_accessible)
    attr_accessible :id, :_id, :name
  end

  # @todo change to real fields
  attr_accessor :owner
  attr_accessor :followers

end
