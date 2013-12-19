class TestCustomKindActivity < Activr::Activity

  set_kind 'my_custom_kind'

  entity :actor, :class => User
  entity :buddy, :class => User

  humanize "{{{actor}}} did something to {{{buddy}}}"

end
