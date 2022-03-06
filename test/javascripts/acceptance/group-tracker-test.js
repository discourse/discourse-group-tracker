import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import Site from "discourse/models/site";
import { test } from "qunit";

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

    assert.ok(
      find("#navigation-bar .group-testing").length === 1,
      "it should display the right nav item"
    );
  });
});
