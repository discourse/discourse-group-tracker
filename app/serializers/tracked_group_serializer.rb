# frozen_string_literal: true

class TrackedGroupSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :full_name

  %w{add_to_navigation_bar tracked_post_icon}.each do |attribute|
    attributes(attribute.to_sym)

    define_method(attribute) do
      object.custom_fields[GroupTracker.key(attribute)]
    end

    define_method("include_#{attribute}?") do
      object.custom_fields[GroupTracker::TRACK_POSTS] &&
      object.custom_fields[GroupTracker.key(attribute)]
    end
  end
end
