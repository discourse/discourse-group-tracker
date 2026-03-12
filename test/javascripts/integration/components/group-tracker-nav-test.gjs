import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import GroupTrackerNav from "discourse/plugins/discourse-group-tracker/discourse/components/group-tracker-nav";

module("Integration | Component | group-tracker-nav", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 100,
      tracked_posts: [
        { post_number: 2, group: "first" },
        { post_number: 4, group: "second" },
      ],
      title: "Qunit Test Topic",
    });
    topic.postStream.set("stream", [100, 200, 300, 500]);
    topic.set("currentPost", 1);

    await render(<template><GroupTrackerNav @topic={{topic}} /></template>);

    assert.dom(".group-tracker-jump-next").exists();
  });
});
