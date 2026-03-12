import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import TextField from "discourse/components/text-field";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class GroupTrackerGroupEdit extends Component {
  @action
  update(name, value) {
    this.args.group.set(name, value);

    return ajax(`/admin/groups/${this.args.group.id}/${name}`, {
      type: "PUT",
      data: this.args.group.getProperties(name),
    });
  }

  <template>
    {{! Only show these fields when editing an existing group }}
    {{#if @group.id}}
      <div class="control-group">
        <label>
          <Input
            {{on
              "change"
              (withEventValue (fn this.update "track_posts") "target.checked")
            }}
            @checked={{@group.track_posts}}
            @type="checkbox"
          />
          {{i18n "group_tracker.track_posts"}}
        </label>

        <label>
          <Input
            {{on
              "change"
              (withEventValue
                (fn this.update "track_posts_with_priority") "target.checked"
              )
            }}
            @checked={{@group.track_posts_with_priority}}
            @type="checkbox"
            disabled={{if @group.track_posts false true}}
          />
          {{i18n "group_tracker.track_posts_with_priority"}}
        </label>

        <label>
          <Input
            {{on
              "change"
              (withEventValue
                (fn this.update "add_to_navigation_bar") "target.checked"
              )
            }}
            @checked={{@group.add_to_navigation_bar}}
            @type="checkbox"
            disabled={{if @group.track_posts false true}}
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
          @value={{@group.tracked_post_icon}}
          @focus-out={{fn this.update "tracked_post_icon"}}
          @placeholderKey="group_tracker.tracked_post_icon.placeholder"
          @disabled={{if @group.track_posts false true}}
        />

        <div class="control-instructions">
          {{i18n "group_tracker.tracked_post_icon.description"}}
        </div>
      </div>
    {{/if}}
  </template>
}
