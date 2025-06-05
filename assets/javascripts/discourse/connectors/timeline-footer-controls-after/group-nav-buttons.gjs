import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import GroupTrackerNav from "../../components/group-tracker-nav";

@tagName("")
@classNames("timeline-footer-controls-after-outlet", "group-nav-buttons")
export default class GroupNavButtons extends Component {
  <template><GroupTrackerNav @topic={{this.model}} /></template>
}
