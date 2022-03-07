import Component from "@ember/component";
import groupTrackerIcon from "discourse/plugins/discourse-group-tracker/lib/group-tracker-icon";
import DiscourseURL from "discourse/lib/url";
import discourseComputed, { on } from "discourse-common/utils/decorators";

export default Component.extend({
  classNames: ["group-tracker-nav"],

  setCurrentPostNumber({ post }) {
    this.set("currentPostNumber", post.post_number);
  },

  @on("init")
  init() {
    this._super(...arguments);
    this.set("currentPostNumber", 1);
    this.appEvents.on(
      "topic:current-post-changed",
      this,
      "setCurrentPostNumber"
    );
  },

  @on("destroy")
  destroy() {
    this.appEvents.off(
      "topic:current-post-changed",
      this,
      "setCurrentPostNumber"
    );
  },

  getPreviousTrackedPost() {
    const topic = this.topic;
    const postStream = topic.get("postStream");
    const stream = postStream.get("stream");

    return (
      topic &&
      topic.tracked_posts &&
      topic.tracked_posts
        .filter((p) => {
          return (
            p.post_number < this.currentPostNumber &&
            stream.includes(postStream.findPostIdForPostNumber(p.post_number))
          );
        })
        .pop()
    );
  },

  getNextTrackedPost() {
    const topic = this.topic;
    const postStream = topic.get("postStream");
    const stream = postStream.get("stream");

    return (
      topic &&
      topic.tracked_posts &&
      topic.tracked_posts.find((p) => {
        return (
          p.post_number > this.currentPostNumber &&
          stream.includes(postStream.findPostIdForPostNumber(p.post_number))
        );
      })
    );
  },

  @discourseComputed("topic", "currentPostNumber")
  nextTrackedPostGroup(topic) {
    const nextTrackedPost = this.getNextTrackedPost(topic);
    return nextTrackedPost ? nextTrackedPost.group : null;
  },

  @discourseComputed("nextTrackedPostGroup")
  nextTrackerIcon(nextTrackedPostGroup) {
    return groupTrackerIcon(nextTrackedPostGroup, this.site, this.siteSettings);
  },

  @discourseComputed("nextTrackedPostGroup", "currentPostNumber")
  nextTrackedPostDisabled(nextTrackedPostGroup) {
    return nextTrackedPostGroup === null;
  },

  @discourseComputed("nextTrackedPostGroup", "prevTrackedPostGroup")
  group_tracker_posts_exists(nextTrackedPostGroup, prevTrackedPostGroup) {
    return nextTrackedPostGroup !== null || prevTrackedPostGroup !== null;
  },

  @discourseComputed("topic", "currentPostNumber")
  prevTrackedPostGroup(topic) {
    const prevTrackedPost = this.getPreviousTrackedPost(topic);
    return prevTrackedPost ? prevTrackedPost.group : null;
  },

  @discourseComputed("prevTrackedPostGroup", "currentPostNumber")
  prevTrackerIcon(prevTrackedPostGroup) {
    return groupTrackerIcon(prevTrackedPostGroup, this.site, this.siteSettings);
  },

  @discourseComputed("prevTrackedPostGroup", "currentPostNumber")
  prevTrackedPostDisabled(prevTrackedPostGroup) {
    return prevTrackedPostGroup === null;
  },

  actions: {
    jumpToNextTrackedPost() {
      const topic = this.topic;
      const nextTrackedPost = this.getNextTrackedPost(topic);

      if (nextTrackedPost) {
        const url = topic.url + "/" + nextTrackedPost.post_number;
        DiscourseURL.routeTo(url);
      }
    },
    jumpToPrevTrackedPost() {
      const topic = this.topic;
      const prevTrackedPost = this.getPreviousTrackedPost(topic);

      if (prevTrackedPost) {
        const url = topic.url + "/" + prevTrackedPost.post_number;
        DiscourseURL.routeTo(url);
      }
    },
  },
});
