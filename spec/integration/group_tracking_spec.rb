# frozen_string_literal: true

require "rails_helper"

describe "Group Tracking" do
  let(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:admin) { Fabricate(:admin) }
  let(:member1) do
    Fabricate(
      :user,
      primary_group: tracked_group,
      groups: [tracked_group],
      refresh_auto_groups: true,
    )
  end

  let(:member2) do
    Fabricate(
      :user,
      primary_group: tracked_group,
      groups: [tracked_group],
      refresh_auto_groups: true,
    )
  end

  let(:member3) do
    Fabricate(
      :user,
      primary_group: another_tracked_group,
      groups: [tracked_group],
      refresh_auto_groups: true,
    )
  end

  let(:priority_member) do
    Fabricate(
      :user,
      primary_group: priority_tracked_group,
      groups: [priority_tracked_group],
      refresh_auto_groups: true,
    )
  end

  let(:tracked_group) do
    group = Fabricate(:group)
    group.custom_fields[GroupTracker::TRACK_POSTS] = true
    group.save
    group
  end

  let(:another_tracked_group) do
    group = Fabricate(:group)
    group.custom_fields[GroupTracker::TRACK_POSTS] = true
    group.save
    group
  end

  let(:priority_tracked_group) do
    group = Fabricate(:group)
    group.custom_fields[GroupTracker::TRACK_POSTS] = true
    group.custom_fields[GroupTracker::PRIORITY_GROUP] = true
    group.save
    group
  end

  context "when toggling 'track_posts' on a group" do
    it "updates existing posts made by members of the group" do
      group = Fabricate(:group)

      member1 = Fabricate(:user, primary_group: group)
      member2 = Fabricate(:user, primary_group: group)

      topic = Fabricate(:topic, user: member1)
      post1 = Fabricate(:post, topic: topic, user: member1)
      post2 = Fabricate(:post, topic: topic, user: user)
      post3 = Fabricate(:post, topic: topic, user: member2)

      sign_in(admin)

      put "/admin/groups/#{group.id}/track_posts.json", params: { track_posts: "true" }

      expect(group.reload.custom_fields[GroupTracker::TRACK_POSTS]).to eq(true)
      expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => group.name,
        "post_number" => 1,
      )
      expect(post1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => group.name,
        "post_number" => 3,
      )
      expect(post2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)

      put "/admin/groups/#{group.id}/track_posts.json", params: { track_posts: "false" }

      expect(group.reload.custom_fields[GroupTracker::TRACK_POSTS]).to eq(false)
      expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      expect(post1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      expect(post2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
    end
  end

  context "when creating tracked posts" do
    let(:raw) { "Hello tracked world!" }

    it "inserts tracking data" do
      sign_in(user)
      post "/posts.json", params: { title: "Topic with tracked posts", raw: raw }

      topic = Topic.last

      sign_in(member1)
      post "/posts.json", params: { topic_id: topic.id, raw: raw }

      sign_in(user)
      post "/posts.json", params: { topic_id: topic.id, raw: raw }

      # we can even opt out of tracking
      sign_in(member2)
      post "/posts.json", params: { topic_id: topic.id, raw: raw, opted_out: "true" }

      sign_in(member1)
      post "/posts.json", params: { topic_id: topic.id, raw: raw }

      topic.reload

      expect(topic.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 2,
      )

      expect(topic.ordered_posts[1].custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 5,
      )

      [0, 2, 3, 4].each do |i|
        expect(topic.ordered_posts[i].custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      end
    end

    context "when the group is a priority group" do
      it "changes the group that the topic is tracking" do
        sign_in(member1)
        post "/posts.json", params: { title: "Topic with tracked posts", raw: raw }
        topic = Topic.last

        topic.reload

        expect(topic.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 1,
        )

        sign_in(priority_member)
        post "/posts.json", params: { topic_id: topic.id, raw: raw }

        topic.reload

        expect(topic.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => priority_tracked_group.name,
          "post_number" => 2,
        )
      end
    end

    context "when the group is not a priority group" do
      it "does not changes the group that the topic is tracking" do
        sign_in(member1)
        post "/posts.json", params: { title: "Topic with tracked posts", raw: raw }
        topic = Topic.last

        topic.reload

        expect(topic.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 1,
        )

        sign_in(member3)
        post "/posts.json", params: { topic_id: topic.id, raw: raw }

        topic.reload

        expect(topic.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 1,
        )
      end
    end
  end

  context "when editing a tracked post" do
    let!(:topic) { Fabricate(:topic, user: user) }
    let!(:post1) { Fabricate(:post, topic: topic, user: user) }
    let!(:post2) { Fabricate(:post, topic: topic, user: member1) }
    let!(:post3) { Fabricate(:post, topic: topic, user: member2) }

    it "resets tracking data when a post changes ownership" do
      sign_in(admin)

      # from a normal user to a tracked user
      post "/t/#{topic.id}/change-owner.json",
           params: {
             post_ids: [post1.id],
             username: member2.username,
           }

      # from a tracked user to a normal user
      post "/t/#{topic.id}/change-owner.json",
           params: {
             post_ids: [post3.id],
             username: user.username,
           }

      expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 1,
      )
      expect(post1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 2,
      )
      expect(post2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      expect(post3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
    end

    context "when the group is a priority group" do
      it "changes the group that the topic is tracking" do
        sign_in(admin)

        # from a normal user to a tracked user
        post "/t/#{topic.id}/change-owner.json",
             params: {
               post_ids: [post1.id],
               username: member2.username,
             }

        # from a tracked user to a normal user
        post "/t/#{topic.id}/change-owner.json",
             params: {
               post_ids: [post3.id],
               username: user.username,
             }

        expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 1,
        )
        expect(post1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 2,
        )

        expect(post2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
        expect(post3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)

        # from a tracked user to a priority group user
        post "/t/#{topic.id}/change-owner.json",
             params: {
               post_ids: [post3.id],
               username: priority_member.username,
             }

        expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => priority_tracked_group.name,
          "post_number" => 3,
        )
      end
    end

    context "when the group is not a priority group" do
      it "does not changes the group that the topic is tracking" do
        sign_in(admin)

        # from a normal user to a tracked user
        post "/t/#{topic.id}/change-owner.json",
             params: {
               post_ids: [post1.id],
               username: member2.username,
             }

        # from a tracked user to a normal user
        post "/t/#{topic.id}/change-owner.json",
             params: {
               post_ids: [post3.id],
               username: user.username,
             }

        expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 1,
        )
        expect(post1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 2,
        )

        expect(post2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
        expect(post3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)

        # from a tracked user to a priority group user
        post "/t/#{topic.id}/change-owner.json",
             params: {
               post_ids: [post3.id],
               username: member3.username,
             }

        expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 1,
        )
      end
    end
  end

  context "when moving a tracked post" do
    let!(:topic) { Fabricate(:topic, user: user) }
    let!(:post1) { Fabricate(:post, topic: topic, user: user) }
    let!(:post2) { Fabricate(:post, topic: topic, user: member1) }
    let!(:post3) { Fabricate(:post, topic: topic, user: member2) }

    it "resets tracking data when a post is moved to another topic" do
      sign_in(admin)
      post "/t/#{topic.id}/move-posts.json",
           params: {
             post_ids: [post2.id],
             title: "This is a valid destination topic title",
           }

      destination_topic = Topic.last

      expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 3,
      )
      expect(post1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      expect(post3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)

      expect(destination_topic.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 1,
      )
      expect(post2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
    end

    context "when the group is a priority group" do
      let!(:post4) { Fabricate(:post, topic: topic, user: priority_member) }
      it "changes the group that the topic is tracking" do
        sign_in(admin)
        post "/t/#{topic.id}/move-posts.json",
             params: {
               post_ids: [post4.id],
               title: "This is a valid destination topic title",
             }

        destination_topic = Topic.last

        expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 2,
        )
        expect(post1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
        expect(post3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)

        expect(destination_topic.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => priority_tracked_group.name,
          "post_number" => 1,
        )

        expect(post2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
          "group" => tracked_group.name,
          "post_number" => 3,
        )
      end
    end
  end

  context "when destroying a tracked post" do
    it "resets tracking data" do
      topic = Fabricate(:topic, user: user)
      post1 = Fabricate(:post, topic: topic, user: user)
      post2 = Fabricate(:post, topic: topic, user: member1)
      post3 = Fabricate(:post, topic: topic, user: member2)

      sign_in(admin)
      delete "/posts/#{post2.id}.json"

      expect(topic.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 3,
      )
      expect(post1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      expect(post2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      expect(post3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
    end
  end

  describe "tracked group membership" do
    it "resets tracking data" do
      user = Fabricate(:user, groups: [tracked_group])
      user2 = Fabricate(:user)

      topic1 = Fabricate(:topic, user: user)
      post1_1 = Fabricate(:post, topic: topic1, user: user)
      post1_2 = Fabricate(:post, topic: topic1, user: user2)
      post1_3 = Fabricate(:post, topic: topic1, user: user)

      topic2 = Fabricate(:topic, user: member1)
      post2_1 = Fabricate(:post, topic: topic2, user: member1)
      post2_2 = Fabricate(:post, topic: topic2, user: user)
      post2_3 = Fabricate(:post, topic: topic2, user: member2)
      post2_4 = Fabricate(:post, topic: topic2, user: user)

      sign_in(admin)

      put "/admin/users/#{user.id}/primary_group.json",
          params: {
            primary_group_id: tracked_group.id,
          }

      expect(topic1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 1,
      )
      expect(post1_1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 3,
      )
      expect(post1_2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      expect(post1_3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)

      expect(topic2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 1,
      )
      expect(post2_1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 2,
      )
      expect(post2_2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 3,
      )
      expect(post2_3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 4,
      )
      expect(post2_4.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)

      put "/admin/users/#{member1.id}/primary_group.json"

      expect(topic2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 2,
      )
      expect(post2_1.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
      expect(post2_2.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 3,
      )
      expect(post2_3.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to eq(
        "group" => tracked_group.name,
        "post_number" => 4,
      )
      expect(post2_4.reload.custom_fields[GroupTracker::TRACKED_POSTS]).to be(nil)
    end
  end
end
