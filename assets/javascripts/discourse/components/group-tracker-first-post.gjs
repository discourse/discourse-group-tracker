import Component from "@glimmer/component";
import { action } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import DButton from "discourse/components/d-button";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class GroupTrackerFirstPost extends Component {
  @readOnly("args.topic.currentPost") postId;

  get disabled() {
    const topic = this.args.topic;
    if (topic.first_tracked_post) {
      const jump_target =
        topic.first_tracked_post.jump_target ||
        topic.first_tracked_post.post_number;
      return jump_target >= this.postId;
    }
    return null;
  }

  @action
  jumpToFirstTrackedPost() {
    const topic = this.args.topic;
    if (topic.first_tracked_post) {
      const jump_target =
        topic.first_tracked_post.jump_target ||
        topic.first_tracked_post.post_number;
      DiscourseURL.jumpToPost(jump_target);
    }
  }

  <template>
    {{#if @topic.first_tracked_post}}
      <DButton
        class="first-tracked-post"
        @icon="circle-arrow-up"
        @title="group_tracker.first_post"
        @disabled={{this.disabled}}
        @action={{this.jumpToFirstTrackedPost}}
        ariaLabel={{i18n "js.group_tracker.first_post"}}
      />
    {{/if}}
  </template>
}
