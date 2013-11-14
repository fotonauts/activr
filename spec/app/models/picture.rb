class Picture

  include Mongoid::Document

  field :title

  # @todo change to real fields
  attr_accessor :owner
  attr_accessor :followers

end
