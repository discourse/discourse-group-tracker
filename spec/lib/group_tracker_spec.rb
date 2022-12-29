# frozen_string_literal: true

require "rails_helper"
require_relative "./../../lib/group_tracker"

describe GroupTracker do
  describe "#should_track?" do
    let(:tracked_group) { build(:group, id: 42) }
    let(:robot) { build(:user, id: -1, primary_group: tracked_group) }
    let(:human) { build(:user, id: 1, primary_group: tracked_group) }

    before { GroupTracker.stubs(:tracked_group_ids).returns([tracked_group.id]) }

    it "does not track posts made by robots" do
      post = build(:post, user: robot)
      expect(GroupTracker.should_track?(post)).to eq(false)
    end

    Post
      .types
      .except(:regular, :moderator_action)
      .keys
      .each do |post_type|
        it "does not track #{post_type} posts" do
          post = build(:post, user: human, post_type: post_type)
          expect(GroupTracker.should_track?(post)).to eq(false)
        end
      end

    it "does not track private messages" do
      topic = build(:topic, archetype: Archetype.private_message)
      post = build(:post, user: human, topic: topic)
      expect(GroupTracker.should_track?(post)).to eq(false)
    end

    it "only tracks posts made by members of tracked groups" do
      group = build(:group, id: 1)
      user = build(:user, id: 1, primary_group: group)
      post = build(:post, user: user)
      expect(GroupTracker.should_track?(post)).to eq(false)

      post = build(:post, user: human)
      expect(GroupTracker.should_track?(post)).to eq(true)

      post = build(:post, user: human, post_type: Post.types[:moderator_action])
      expect(GroupTracker.should_track?(post)).to eq(true)
    end

    it "works with posts of deleted users" do
      user = Fabricate(:user)
      post = Fabricate(:post, user: user)
      user.destroy!

      expect(GroupTracker.should_track?(post.reload)).to eq(false)
    end
  end
end
