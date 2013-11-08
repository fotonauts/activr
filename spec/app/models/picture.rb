class Picture

  include Mongoid::Document

  field :title

  # @todo change to a real field
  attr_accessor :owner

end
