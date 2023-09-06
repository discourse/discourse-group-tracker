# coding: utf-8
# frozen_string_literal: true

# name: discourse-group-tracker
# about: Group Tracker plugin for Discourse
# version: 1.0
# author: Régis Hanol
# transpile_js: true

register_asset "stylesheets/group-tracker.scss"

after_initialize do
  load File.expand_path("../lib/group_tracker.rb", __FILE__)
  load File.expand_path("../app/serializers/tracked_group_serializer.rb", __FILE__)

  Discourse::Application.routes.append do
    namespace :admin, constraints: AdminConstraint.new do
      put "groups/:id/track_posts" => "groups#update_track_posts", :constraints => { id: /\d+/ }
      put "groups/:id/add_to_navigation_bar" => "groups#update_add_to_navigation_bar",
          :constraints => {
            id: /\d+/,
          }
      put "groups/:id/tracked_post_icon" => "groups#update_tracked_post_icon",
          :constraints => {
            id: /\d+/,
          }
    end
  end

  register_group_custom_field_type(GroupTracker.key("track_posts"), :boolean)
  register_group_custom_field_type(GroupTracker.key("add_to_navigation_bar"), :boolean)

  register_svg_icon "arrow-circle-up" if respond_to?(:register_svg_icon)
  register_svg_icon "crown" if respond_to?(:register_svg_icon)
  register_svg_icon "arrow-right" if respond_to?(:register_svg_icon)
  register_svg_icon "arrow-left" if respond_to?(:register_svg_icon)

  GroupTracker::GROUP_ATTRIBUTES.each do |attribute|
    add_preloaded_group_custom_field(GroupTracker.key(attribute))

    # GroupShowSerializer extends BasicGroup but in production mode the
    # child doesn't pick up the parent's changes.
    %i[basic_group group_show].each do |s|
      add_to_serializer(s, attribute.to_sym, include_condition: -> do 
                          object.custom_fields[GroupTracker::TRACK_POSTS]
                        end) do
        object.custom_fields[GroupTracker.key(attribute)]
      end
    end
  end

  add_to_class(Admin::GroupsController, :update_track_posts) do
    track_posts = params[:track_posts] == "true"

    group = Group.find(params[:id])
    group.custom_fields[GroupTracker.key("track_posts")] = track_posts
    group.save

    GroupTracker.update_tracking!

    render json: success_json
  end

  add_to_class(Admin::GroupsController, :update_add_to_navigation_bar) do
    group = Group.find(params[:id])
    group.custom_fields[GroupTracker.key("add_to_navigation_bar")] = params[
      :add_to_navigation_bar
    ] == "true"
    group.save

    render json: success_json
  end

  add_to_class(Admin::GroupsController, :update_tracked_post_icon) do
    group = Group.find(params[:id])
    group.custom_fields[GroupTracker.key("tracked_post_icon")] = params[:tracked_post_icon].presence
    group.save

    render json: success_json
  end

  TRACKED_GROUPS ||= "tracked_groups".freeze

  add_to_serializer(:site, :tracked_groups) do
    cache_fragment(TRACKED_GROUPS) do
      tracked_groups = Group.where(id: GroupTracker.tracked_group_ids)
      Group.preload_custom_fields(tracked_groups, Group.preloaded_custom_field_names)
      ActiveModel::ArraySerializer.new(
        tracked_groups,
        each_serializer: TrackedGroupSerializer,
      ).as_json
    end
  end

  add_model_callback(Group, :after_save) do
    ApplicationSerializer.expire_cache_fragment!(TRACKED_GROUPS)
  end

  add_model_callback(Group, :after_destroy) do
    ApplicationSerializer.expire_cache_fragment!(TRACKED_GROUPS)
  end

  register_topic_custom_field_type(GroupTracker::TRACKED_POSTS, :json)
  add_preloaded_topic_list_custom_field(GroupTracker::TRACKED_POSTS)

  add_to_serializer(:topic_list_item, :first_tracked_post, include_condition: -> do
                      object.custom_fields[GroupTracker::TRACKED_POSTS].present?
                    end) do
    object.custom_fields[GroupTracker::TRACKED_POSTS]
  end

  add_to_serializer(:topic_view, :first_tracked_post, include_condition: -> do
                      object.topic.custom_fields[GroupTracker::TRACKED_POSTS].present?
                    end) do
    object.topic.custom_fields[GroupTracker::TRACKED_POSTS]
  end

  add_to_serializer(:topic_view, :tracked_posts, include_condition: -> do
                      object.topic.custom_fields[GroupTracker::TRACKED_POSTS].present?
                    end) do
    tracked_posts = []

    tracked_posts << object.topic.custom_fields[GroupTracker::TRACKED_POSTS]

    object.post_custom_fields.keys.sort.each do |post_id|
      if object.post_custom_fields[post_id][GroupTracker::TRACKED_POSTS]
        tracked_posts << object.post_custom_fields[post_id][GroupTracker::TRACKED_POSTS]
      end
    end

    tracked_posts.compact
  end

  add_to_serializer(:post, :next_tracked_post, include_condition: -> do
                      post_custom_fields[GroupTracker::TRACKED_POSTS].present?
                    end) do
    post_custom_fields[GroupTracker::TRACKED_POSTS]
  end

  register_post_custom_field_type(GroupTracker::OPTED_OUT, :boolean)
  register_post_custom_field_type(GroupTracker::TRACKED_POSTS, :json)

  topic_view_post_custom_fields_allowlister do
    [GroupTracker::TRACKED_POSTS, GroupTracker::OPTED_OUT]
  end

  add_to_serializer(:post, :opted_out, include_condition: -> do
                      post_custom_fields[GroupTracker::OPTED_OUT]
                    end) { post_custom_fields[GroupTracker::OPTED_OUT] }

  add_permitted_post_create_param("opted_out")

  on(:post_created) do |post, opts|
    next unless GroupTracker.should_track?(post)

    if opts["opted_out"]
      post.custom_fields[GroupTracker::OPTED_OUT] = true
      post.save_custom_fields(true)
    else
      GroupTracker.update_tracking!(post.topic_id)
    end

    nil
  end

  on(:post_edited) do |post|
    next unless post.archetype != Archetype.private_message

    # we're only concerned when there was an ownership change
    next unless user_ids = post.previous_changes["user_id"]
    # and only if a human was concerned
    next unless user_ids.any? { |id| id > 0 }

    primary_group_ids = User.where(id: user_ids).pluck(:primary_group_id)

    next unless (GroupTracker.tracked_group_ids & primary_group_ids).present?

    GroupTracker.update_tracking!(post.topic_id)

    nil
  end

  on(:post_moved) do |post, previous_topic_id|
    next unless GroupTracker.should_track?(post)

    GroupTracker.update_tracking!(post.topic_id)
    GroupTracker.update_tracking!(previous_topic_id)

    nil
  end

  on(:post_destroyed) do |post|
    next unless GroupTracker.should_track?(post)

    GroupTracker.update_tracking!(post.topic_id)

    nil
  end

  add_model_callback(User, :after_commit, on: :update) do
    # we only care when the primary_group_id has changed...
    next unless primary_group_ids = self.previous_changes["primary_group_id"]

    # ... and only if either is tracked
    next unless (GroupTracker.tracked_group_ids & primary_group_ids).present?

    GroupTracker.update_tracking!
  end
end
