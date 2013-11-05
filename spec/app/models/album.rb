class Album

  include Mongoid::Document

  field :name

  def owner
    # @todo
    raise "not implemented"
  end

end
