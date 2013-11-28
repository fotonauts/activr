class User

  include Mongoid::Document

  field :_id, :type => String

  field :first_name
  field :last_name

  field :nil_field

  # @todo change to a real field
  attr_accessor :followers

  def fullname
    "#{self.first_name} #{self.last_name}"
  end

  def blank_meth
    ""
  end

  # I know this is bad, this is just for testing purpose
  def to_html
    "<span class='user'>#{fullname}<span>"
  end

end
