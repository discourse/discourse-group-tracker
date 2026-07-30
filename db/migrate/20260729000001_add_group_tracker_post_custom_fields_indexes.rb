# frozen_string_literal: true
class AddGroupTrackerPostCustomFieldsIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_post_custom_fields_on_group_tracker_tracked_posts
    SQL
    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_post_custom_fields_on_group_tracker_tracked_posts
      ON post_custom_fields (post_id)
      WHERE name = 'group_tracker_tracked_posts'
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_post_custom_fields_on_group_tracker_opted_out
    SQL
    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_post_custom_fields_on_group_tracker_opted_out
      ON post_custom_fields (post_id)
      WHERE name = 'group_tracker_opted_out'
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_post_custom_fields_on_group_tracker_tracked_posts
    SQL
    execute <<~SQL
      DROP INDEX IF EXISTS index_post_custom_fields_on_group_tracker_opted_out
    SQL
  end
end
