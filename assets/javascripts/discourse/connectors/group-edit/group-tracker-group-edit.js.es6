import { ajax } from "discourse/lib/ajax";

function update(group, name, value) {
  group.set(name, value);

  return ajax(`/admin/groups/${group.id}/${name}`, {
    type: "PUT",
    data: group.getProperties(name),
  });
}

export default {
  actions: {
    trackPostsChanged(value) {
      update(this.args.group, "track_posts", value);
    },

    addToNavigationBarChanged(value) {
      update(this.args.group, "add_to_navigation_bar", value);
    },

    trackedPostIconChanged(value) {
      update(this.args.group, "tracked_post_icon", value);
    },
  },
};
