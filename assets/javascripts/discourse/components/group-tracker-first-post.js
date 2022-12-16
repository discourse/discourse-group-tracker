import { action } from "@ember/object";
import Component from "@glimmer/component";
import DiscourseURL from "discourse/lib/url";
import { alias } from "@ember/object/computed";

export default class GroupTrackerFirstPost extends Component {
  @alias("args.topic.currentPost") postId;

  get disabled() {
    if (this.args.topic.first_tracked_post) {
      return this.args.topic.first_tracked_post.post_number >= this.postId;
    }
    return null;
  }

  @action
  jumpToFirstTrackedPost() {
    const topic = this.args.topic;
    if (topic.first_tracked_post) {
      DiscourseURL.jumpToPost(topic.first_tracked_post.post_number);
    }
  }
}
