class Picture

  include Mongoid::Document

  field :title

  def owner
    # @todo
    raise "not implemented"
  end

end
