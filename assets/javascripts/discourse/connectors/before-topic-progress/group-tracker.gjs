import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import GroupTrackerNav from "../../components/group-tracker-nav";

@tagName("div")
@classNames("before-topic-progress-outlet", "group-tracker")
export default class GroupTracker extends Component {
  <template>
    <GroupTrackerNav @topic={{this.model}} @jumpToPost={{this.jumpToPost}} />
  </template>
}
