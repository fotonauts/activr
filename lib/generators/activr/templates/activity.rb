# encoding: utf-8

class <%= class_name %>Activity < Activr::Activity
<% if entities_infos.blank? %>
  # entity :actor, :class => User
  # entity :buddy, :class => User

  # def humanize
  #   Activr.sentence("{{actor.fullname}} is now following {{buddy.fullname}}")
  # end
<% else %>
<% entities_infos.each do |entity| -%>
  entity :<%= entity[:name] %>, :class => <%= entity[:class] %>
<% end -%>

  def humanize
    Activr.sentence("<%= humanization %>")
  end
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
