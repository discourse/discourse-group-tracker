import EmberObject from "@ember/object";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import GroupTrackerTopicStatus from "../components/group-tracker-topic-status";


export default class extends EmberObject {
    get html() {
    return rawRenderGlimmer(
      this,
      "tracker-topic-status",
      <template><GroupTrackerTopicStatus @context={{@data}} /></template>,
      this.context
    );
  }
}