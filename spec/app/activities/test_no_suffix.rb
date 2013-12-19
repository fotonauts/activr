class TestNoSuffix < Activr::Activity

  entity :actor, :class => User, :humanize => :fullname
  entity :picture, :humanize => :title
  entity :album, :humanize => :name

  humanize "{{{actor}}} did something with {{{picture}}} in the album {{{album}}}"

end
