import { acceptance, count } from "discourse/tests/helpers/qunit-helpers";
import Site from "discourse/models/site";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Group tracker", function (needs) {
  needs.user();

  test("Nav bar item is present", async (assert) => {
    Site.current().set("tracked_groups", [
      {
        id: 1,
        add_to_navigation_bar: true,
        name: "testing",
        full_name: "testing",
      },
    ]);

    await visit("/");

    assert.strictEqual(
      count("#navigation-bar .group-testing"),
      1,
      "it should display the right nav item"
    );
  });
});
