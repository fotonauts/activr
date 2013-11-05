class User

  include Mongoid::Document

  field :first_name
  field :last_name

  def fullname
    "#{self.first_name} #{self.last_name}"
  end

  def followers
    # @todo
    raise "not implemented"
  end

end
