# an activity class with Activity suffix
class AddBuddyActivity < Activr::Activity

  entity :actor, :class => User
  entity :buddy, :class => User

  def humanize(options = { })
    bindings = {
      :actor => self.actor.fullname,
      :buddy => self.buddy.fullname,
    }

    Activr.sentence("{{{actor}}} is now following {{{buddy}}}", bindings)
  end

end
