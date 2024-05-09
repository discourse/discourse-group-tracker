# frozen_string_literal: true

module GroupTracker
  GROUP_ATTRIBUTES ||= %w[
    track_posts
    track_posts_with_priority
    add_to_navigation_bar
    tracked_post_icon
  ]

  def self.key(name)
    "group_tracker_#{name}"
  end

  OPTED_OUT ||= key("opted_out")
  TRACK_POSTS ||= key("track_posts")
  TRACKED_POSTS ||= key("tracked_posts")
  PRIORITY_GROUP ||= key("track_posts_with_priority")

  def self.priority_tracked_group_ids
    GroupCustomField.where(name: PRIORITY_GROUP, value: "t").pluck(:group_id)
  end

  def self.tracked_group_ids
    GroupCustomField.where(name: TRACK_POSTS, value: "t").pluck(:group_id)
  end

  def self.should_track?(post)
    post.user_id > 0 &&
      (post.post_type == Post.types[:regular] || post.post_type == Post.types[:moderator_action]) &&
      post.archetype != Archetype.private_message && post.user.present? &&
      tracked_group_ids.include?(post.user.primary_group_id)
  end

  def self.update_tracking!(topic_id = nil)
    Scheduler::Defer.later "Updating tracked posts" do
      update_tracking_on_topics!(topic_id)
      update_tracking_posts!(topic_id)
    end
  end

  private

  def self.update_tracking_on_topics!(topic_id = nil)
    builder = DB.build <<~SQL
        WITH "tracked_posts_priority" AS (
            SELECT p.topic_id
                 , row_number() OVER (PARTITION BY p.topic_id ORDER BY p.topic_id, p.id) "row"
                 , p.post_number
                 , p.id "post_id"
                 , u.primary_group_id "group_id"
              FROM "posts" p
              JOIN "users" u  ON u.id = p.user_id
              JOIN "topics" t ON t.id = p.topic_id
         LEFT JOIN "post_custom_fields" pcf ON pcf.post_id = p.id AND pcf.name = :opted_out_name
             /*where*/
             AND u.primary_group_id IN (:priority_tracked_group_ids)
          ORDER BY p.topic_id, p.id
), "tracked_posts_low_priority" AS (
            SELECT p.topic_id
                 , row_number() OVER (PARTITION BY p.topic_id ORDER BY p.topic_id, p.id) "row"
                 , p.post_number
                 , p.id "post_id"
                 , u.primary_group_id "group_id"
              FROM "posts" p
              JOIN "users" u  ON u.id = p.user_id
              JOIN "topics" t ON t.id = p.topic_id
         LEFT JOIN "post_custom_fields" pcf ON pcf.post_id = p.id AND pcf.name = :opted_out_name
             /*where*/
        	    AND NOT EXISTS(
        			SELECT pri.topic_id
        			FROM tracked_posts_priority pri
        			WHERE pri.topic_id = t.id
        		)
          ORDER BY p.topic_id, p.id
        ), "tracked_posts" AS (
          SELECT * FROM tracked_posts_priority
          UNION SELECT * FROM tracked_posts_low_priority
        ), "tracked_data" AS (
            SELECT topic_id, json_build_object('group', name, 'post_number', post_number)::text "data"
              FROM "tracked_posts"
              JOIN "groups" g ON g.id = group_id
             WHERE "row" = 1
        ), "cleaned_topics" AS (
            DELETE
              FROM "topic_custom_fields"
             /*where2*/
        ), "updated_topics" AS (
             UPDATE "topic_custom_fields" AS tcf
                SET "value" = td.data, updated_at = now()
               FROM "tracked_data" td
              WHERE tcf.topic_id = td.topic_id
                AND tcf.name = :custom_field_name
                AND tcf.value <> td.data
          RETURNING tcf.topic_id
        )
        INSERT INTO "topic_custom_fields" (created_at, updated_at, name, value, topic_id)
        SELECT now(), now(), :custom_field_name, data, td.topic_id
          FROM "tracked_data" td
         WHERE td.topic_id NOT IN (SELECT topic_id FROM "updated_topics")
           AND td.topic_id NOT IN (SELECT topic_id FROM "topic_custom_fields" WHERE name = :custom_field_name)
      SQL

    builder.where <<~SQL
        p.post_type IN (1, 2)
        AND p.deleted_at IS NULL
        AND t.archetype = 'regular'
        AND t.deleted_at IS NULL
        AND u.id > 0
        AND u.primary_group_id IN (:tracked_group_ids)
        AND (pcf.value IS NULL OR pcf.value <> 't')
      SQL

    builder.where2("name = :custom_field_name")

    if topic_id
      builder.where("p.topic_id = :topic_id", topic_id: topic_id)
      builder.where2("'f'")
    else
      builder.where2("topic_id NOT IN (SELECT topic_id FROM tracked_data)")
    end

    builder.exec(
      tracked_group_ids: tracked_group_ids,
      priority_tracked_group_ids: priority_tracked_group_ids,
      opted_out_name: key("opted_out"),
      custom_field_name: key("tracked_posts"),
    )
  end

  def self.update_tracking_posts!(topic_id = nil)
    builder = DB.build <<~SQL
        WITH "tracked_posts" AS (
            SELECT p.topic_id
                 , row_number() OVER (PARTITION BY p.topic_id ORDER BY p.topic_id, p.id) "row"
                 , p.post_number
                 , p.id "post_id"
                 , u.primary_group_id "group_id"
              FROM "posts" p
              JOIN "users" u  ON u.id = p.user_id
              JOIN "topics" t ON t.id = p.topic_id
         LEFT JOIN "post_custom_fields" pcf ON pcf.post_id = p.id AND pcf.name = :opted_out_name
             /*where*/
          ORDER BY p.topic_id, p.id
        ), "tracked_data" AS (
            SELECT tp.post_id, json_build_object('group', name, 'post_number', tp_next.post_number)::text "data"
              FROM "tracked_posts" tp
              JOIN "tracked_posts" tp_next ON tp.topic_id = tp_next.topic_id
              JOIN "groups" g ON g.id = tp_next.group_id
             WHERE tp.row = tp_next.row - 1
          GROUP BY tp.topic_id, tp.post_id, g.name, tp_next.post_number
        ), "cleaned_posts" AS (
            DELETE
              FROM "post_custom_fields"
              /*where2*/
        ), "updated_posts" AS (
             UPDATE "post_custom_fields" AS pcf
                SET "value" = td.data, updated_at = now()
               FROM "tracked_data" td
              WHERE pcf.post_id = td.post_id
                AND pcf.name = :custom_field_name
                AND pcf.value <> td.data
          RETURNING pcf.post_id
        )
        INSERT INTO "post_custom_fields" (created_at, updated_at, name, value, post_id)
        SELECT now(), now(), :custom_field_name, data, td.post_id
          FROM "tracked_data" td
         WHERE td.post_id NOT IN (SELECT post_id FROM "updated_posts")
           AND td.post_id NOT IN (SELECT post_id FROM "post_custom_fields" WHERE name = :custom_field_name)
      SQL

    builder.where <<~SQL
        p.post_type IN (1, 2)
        AND p.deleted_at IS NULL
        AND t.archetype = 'regular'
        AND t.deleted_at IS NULL
        AND u.id > 0
        AND u.primary_group_id IN (:tracked_group_ids)
        AND (pcf.value IS NULL OR pcf.value <> 't')
      SQL

    builder.where2("name = :custom_field_name")
    builder.where2("post_id NOT IN (SELECT post_id FROM tracked_data)")

    if topic_id
      builder.where("p.topic_id = :topic_id", topic_id: topic_id)
      builder.where2("post_id IN (SELECT id FROM posts WHERE topic_id = :topic_id)")
    end

    builder.exec(
      tracked_group_ids: tracked_group_ids,
      opted_out_name: key("opted_out"),
      custom_field_name: key("tracked_posts"),
    )
  end
end
