import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import GroupTrackerFirstPost from "../../components/group-tracker-first-post";

@tagName("")
@classNames("timeline-controls-before-outlet", "first-tracked-post")
export default class FirstTrackedPost extends Component {
  <template><GroupTrackerFirstPost @topic={{this.model}} /></template>
}
