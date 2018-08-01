import { acceptance } from "helpers/qunit-helpers";

acceptance("Group tracker", {
  loggedIn: true
});

test("Nav bar item is present", async assert => {
  Discourse.Site.current().set("tracked_groups", [
    {
      id: 1,
      add_to_navigation_bar: true,
      name: "testing",
      full_name: "testing"
    }
  ]);

  await visit("/");

  assert.ok(
    find("#navigation-bar .group-testing").length === 1,
    "it should display the right nav item"
  );
});
