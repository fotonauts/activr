# encoding: utf-8

class <%= class_name %>Activity < Activr::Activity
<% if entities_infos.blank? %>
  # entity :actor, :class => User, :humanize => :fullname
  # entity :buddy, :class => User, :humanize => :fullname

  # humanize "{{{actor}}} is now following {{{buddy}}}"
<% else %>
<% entities_infos.each do |entity| -%>
  entity :<%= entity[:name] %><% if entity[:class] %>, :class => <%= entity[:class] %><% end %>, :humanize => :<%= entity[:humanize] %>
<% end -%>

  humanize "<%= humanization %>"
<% end %><% if options[:full] %>
  #
  # callbacks
  #

  # activity is stored in main collection
  # before_store :check_stuff
  # after_store :notify_stuff

  # activity is routed to all timelines
  # before_route :check_stuff
  # after_route :notify_stuff
<% end %>
end
