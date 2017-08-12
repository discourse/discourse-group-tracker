class Admin::GroupsController < Admin::AdminController

  def toggle_track_posts
    track_posts = params[:track_posts] == "true"

    group = Group.find(params[:id])
    group.custom_fields[GroupTracker.key("track_posts")] = track_posts
    group.save

    GroupTracker.update_tracking!

    render json: success_json
  end

  (GroupTracker::GROUP_ATTRIBUTES - ["track_posts"]).each do |action|
    define_method("toggle_#{action}") do
      group = Group.find(params[:id])
      group.custom_fields[GroupTracker.key(action)] = params[action.to_sym] == "true"
      group.save

      render json: success_json
    end
  end

end
