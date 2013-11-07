class User

  include Mongoid::Document

  field :_id, :type => String

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
