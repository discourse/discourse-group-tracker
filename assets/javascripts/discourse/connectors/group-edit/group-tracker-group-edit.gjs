import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import TextField from "discourse/components/text-field";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class GroupTrackerGroupEdit extends Component {
  @tracked group = this.args.outletArgs.group;

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

  <template>
    {{! Only show these fields when editing an existing group }}
    {{#if this.group.id}}
      <div class="control-group">

        <label>
          <Input
            @type="checkbox"
            @checked={{this.group.track_posts}}
            {{on
              "change"
              (action this.trackPostsChanged value="target.checked")
            }}
          />
          {{i18n "group_tracker.track_posts"}}
        </label>

        <label>
          <Input
            @type="checkbox"
            @checked={{this.group.track_posts_with_priority}}
            disabled={{if this.group.track_posts false true}}
            {{on
              "change"
              (action this.trackedPostPriorityGroup value="target.checked")
            }}
          />
          {{i18n "group_tracker.track_posts_with_priority"}}
        </label>

        <label>
          <Input
            @type="checkbox"
            @checked={{this.group.add_to_navigation_bar}}
            disabled={{if this.group.track_posts false true}}
            {{on
              "change"
              (action this.addToNavigationBarChanged value="target.checked")
            }}
          />
          {{i18n "group_tracker.add_to_navigation_bar"}}
        </label>

      </div>

      <div class="control-group">
        <label for="tracked_post_icon">
          {{i18n "group_tracker.tracked_post_icon.label"}}
        </label>
        <TextField
          @name="tracked_post_icon"
          @value={{this.group.tracked_post_icon}}
          @focus-out={{this.trackedPostIconChanged}}
          @placeholderKey="group_tracker.tracked_post_icon.placeholder"
          @disabled={{if this.group.track_posts false true}}
        />
        <div class="control-instructions">
          {{i18n "group_tracker.tracked_post_icon.description"}}
        </div>
      </div>
    {{/if}}
  </template>
}
