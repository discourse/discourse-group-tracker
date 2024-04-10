import Component from "@glimmer/component";
import DiscourseURL from "discourse/lib/url";
import { inject as service } from "@ember/service";
import I18n from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";

export default class GroupTrackerTopicStatus extends Component {
  @service site;

  context = this.args.context;

  get titleName() {
    const trackedGroups = this.site && this.site.tracked_groups;
    const trackedGroup = trackedGroups.find(g => g.name === this.context.topic.first_tracked_post.group)
    let title = "";

    if(trackedGroup){
      const name =  trackedGroup.full_name ? trackedGroup.full_name : trackedGroup.name;
      title= I18n.t("group_tracker.first_group_post", {group: name});
    }

    return title;
    }

  <template>
    {{log this}}
    {{log this.context.topic}}
    {{log this.context.topic.first_tracked_post}}
    <span class="topic-icon-container">
      {{#if this.context.topic.first_tracked_post}}
        <a class="tracked-post group-{{this.context.topic.first_tracked_post.group}}" href="{{this.context.topic.url}}/{{this.context.topic.first_tracked_post.post_number}}" title="{{this.titleName}}">
          {{icon this.context.topic.firstTrackedPostIcon class="first-tracked-post"}}
          {{#if this.context.siteSettings.group_tracker_topic_icon}}
            {{icon this.context.siteSettings.group_tracker_topic_icon class=this.context.siteSettings.group_tracker_topic_icon_class}}
          {{/if}}
        </a>
      {{else}}
        {{#if this.context.siteSettings.group_tracker_topic_icon}}
          {{icon this.context.siteSettings.group_tracker_topic_icon class=this.context.siteSettings.group_tracker_topic_icon_class}}
        {{/if}}
      {{/if}}
    </span>
  </template>
}

 
 


