class Album

  include Mongoid::Document

  field :name

  # @todo change to real fields
  attr_accessor :owner
  attr_accessor :followers

end
