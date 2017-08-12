import { ajax } from "discourse/lib/ajax";

function toggle(group, name, value) {
  group.set(name, value);

  return ajax(`/admin/groups/${group.id}/toggle_${name}`, {
    type: "PUT",
    data: group.getProperties(name)
  });
}

export default {
  actions: {
    toggleTrackPosts(value) {
      toggle(this.args.group, "track_posts", value);
    },

    toggleAddToNavigationBar(value) {
      toggle(this.args.group, "add_to_navigation_bar", value);
    },

    // toggleAddLinkInTopicsList(value) {
    //   toggle(this.args.group, "add_link_in_topics_list", value);
    // },

    // toggleAddNextButtonOnPost(value) {
    //   toggle(this.args.group, "add_next_button_on_post", value);
    // },

    // toggleAddFirstButtonAboveTimeline(value) {
    //   toggle(this.args.group, "add_first_button_above_timeline", value);
    // },

    // toggleAddNextButtonBelowTimeline(value) {
    //   toggle(this.args.group, "add_next_button_below_timeline", value);
    // }
  }
};
