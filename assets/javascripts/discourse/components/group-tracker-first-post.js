import Component from "@glimmer/component";
import { action } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import DiscourseURL from "discourse/lib/url";

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
}
