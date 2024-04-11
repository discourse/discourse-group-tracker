import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
export default class GroupTrackerGroupEdit extends Component {
  @service siteSettings;
  @tracked group = this.args.outletArgs.group ;

  update(group, name, value) {
    group.set(name, value);

    return ajax(`/admin/groups/${group.id}/${name}`, {
      type: "PUT",
      data: group.getProperties(name),
    });
  }

  @action
  trackPostsChanged(value) {
    this.update(this.group, "track_posts", value);
  }

  @action
  trackedPostPriorityGroup(value) {
    if (!this.siteSettings.group_tracker_priority_group) {
      return;
    }

    this.update(this.group, "track_posts_with_priority", value);
  }

  @action
  addToNavigationBarChanged(value) {
    this.update(this.group, "add_to_navigation_bar", value);
  }

  @action
  trackedPostIconChanged(value) {
    this.update(this.group, "tracked_post_icon", value);
  }
}