import Component from "@glimmer/component";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import groupTrackerIcon from "discourse/plugins/discourse-group-tracker/lib/group-tracker-icon";

export default class GroupTrackerNav extends Component {
  @service site;
  @service siteSettings;

  @alias("args.topic.currentPost") postId;

  getPreviousTrackedPost() {
    const topic = this.args.topic;
    const postStream = topic.get("postStream");
    const stream = postStream.get("stream");

    return (
      topic &&
      topic.tracked_posts &&
      topic.tracked_posts
        .slice()
        .reverse()
        .find((p) => {
          return (
            p.post_number < this.postId &&
            stream.includes(postStream.findPostIdForPostNumber(p.post_number))
          );
        })
    );
  }

  getNextTrackedPost() {
    const topic = this.args.topic;
    const postStream = topic.get("postStream");
    const stream = postStream.get("stream");

    return (
      topic &&
      topic.tracked_posts &&
      topic.tracked_posts.find((p) => {
        return (
          p.post_number > this.postId &&
          stream.includes(postStream.findPostIdForPostNumber(p.post_number))
        );
      })
    );
  }

  get nextTrackedPostGroup() {
    const nextTrackedPost = this.getNextTrackedPost();
    return nextTrackedPost ? nextTrackedPost.group : null;
  }

  get nextTrackerIcon() {
    return groupTrackerIcon(
      this.nextTrackedPostGroup,
      this.site,
      this.siteSettings
    );
  }

  get nextTrackedPostDisabled() {
    return this.nextTrackedPostGroup === null;
  }

  get groupTrackerPostsExist() {
    return (
      this.nextTrackedPostGroup !== null || this.prevTrackedPostGroup !== null
    );
  }

  get prevTrackedPostGroup() {
    const prevTrackedPost = this.getPreviousTrackedPost();
    return prevTrackedPost ? prevTrackedPost.group : null;
  }

  get prevTrackerIcon() {
    return groupTrackerIcon(
      this.prevTrackedPostGroup,
      this.site,
      this.siteSettings
    );
  }

  get prevTrackedPostDisabled() {
    return this.prevTrackedPostGroup === null;
  }

  @action
  jumpToNextTrackedPost() {
    const nextTrackedPost = this.getNextTrackedPost();

    if (nextTrackedPost) {
      const url = this.args.topic.url + "/" + nextTrackedPost.post_number;
      DiscourseURL.routeTo(url);
    }
  }

  @action
  jumpToPrevTrackedPost() {
    const prevTrackedPost = this.getPreviousTrackedPost();

    if (prevTrackedPost) {
      const url = this.args.topic.url + "/" + prevTrackedPost.post_number;
      DiscourseURL.routeTo(url);
    }
  }
}
