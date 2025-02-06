import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class GroupTrackerTopicStatus extends Component {
  @service site;
  @service siteSettings;

  get titleName() {
    const trackedGroups = this.site && this.site.tracked_groups;
    const trackedGroup = trackedGroups.find(
      (g) => g.name === this.args.topic.first_tracked_post.group
    );
    let title = "";

    if (trackedGroup) {
      const name = trackedGroup.full_name
        ? trackedGroup.full_name
        : trackedGroup.name;
      title = i18n("group_tracker.first_group_post", { group: name });
    }

    return title;
  }

  <template>
    <span class="topic-icon-container">
      {{#if @topic.first_tracked_post}}
        <a
          class="tracked-post group-{{@topic.first_tracked_post.group}}"
          href="{{@topic.url}}/{{@topic.first_tracked_post.post_number}}"
          title={{this.titleName}}
        >
          {{icon @topic.firstTrackedPostIcon class="first-tracked-post"}}
          {{#if this.siteSettings.group_tracker_topic_icon}}
            {{icon
              this.siteSettings.group_tracker_topic_icon
              class=this.siteSettings.group_tracker_topic_icon_class
            }}
          {{/if}}
        </a>
      {{else}}
        {{#if this.siteSettings.group_tracker_topic_icon}}
          {{icon
            this.siteSettings.group_tracker_topic_icon
            class=this.siteSettings.group_tracker_topic_icon_class
          }}
        {{/if}}
      {{/if}}
    </span>
  </template>
}
