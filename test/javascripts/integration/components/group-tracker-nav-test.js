import { getOwner } from "@ember/application";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | group-tracker-nav", function (hooks) {
  setupRenderingTest(hooks);

  test("It renders", async function (assert) {
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
    this.set("topic", topic);
    await render(hbs`<GroupTrackerNav @topic={{this.topic}}/>`);

    assert.ok(exists(".group-tracker-jump-next"));
  });
});
