import computed from "discourse/lib/decorators";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer from "discourse/models/composer";
import groupTrackerIcon from "discourse/plugins/discourse-group-tracker/lib/group-tracker-icon";

const PLUGIN_ID = "discourse-group-tracker";

function modifyTopicModel(api) {
  api.modifyClass(
    "model:topic",
    (Superclass) =>
      class extends Superclass {
        // used in the 'topic-list-before-status' connector
        @computed("first_tracked_post.group")
        firstTrackedPostIcon(group) {
          return groupTrackerIcon(group, this.site, this.siteSettings);
        }
      }
  );
}

function addTrackedGroupToTopicList(api) {
  api.registerValueTransformer(
    "topic-list-item-class",
    ({ value: classNames, context }) => {
      const firstTrackedPost = context.topic.first_tracked_post;
      if (firstTrackedPost) {
        classNames.push(`group-${firstTrackedPost.group}`);
      }
      return classNames;
    }
  );

  withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
    api.modifyClass(
      "component:topic-list-item",
      (Superclass) =>
        class extends Superclass {
          @computed("topic.first_tracked_post")
          unboundClassNames(firstTrackedPost) {
            let classNames = super.unboundClassNames;

            if (firstTrackedPost) {
              classNames += ` group-${firstTrackedPost.group}`;
            }

            return classNames;
          }
        }
    );
  });
}

function addNavigationBarItems(api) {
  const { tracked_groups } = api.container.lookup("service:site");

  if (!tracked_groups) {
    return;
  }

  tracked_groups
    .filter((g) => g.add_to_navigation_bar)
    .forEach((g) => {
      let groupId = `group-${g.name}`;
      api.addNavigationBarItem({
        name: groupId,
        displayName: g.full_name,
        title: g.full_name,
        classNames: groupId,
        href: getURL(`/g/${g.name}/activity/posts`),
        includeCategoryId: true,
      });
    });
}

function addOptOutClassOnPost(api) {
  api.includePostAttributes("opted_out");
  api.addPostClassesCallback((p) => p.opted_out && ["opted-out"]);
}

function addOptOutToggle(api) {
  const ALLOWED_COMPOSER_ACTIONS = [Composer.CREATE_TOPIC, Composer.REPLY];

  api.modifyClass("component:composer-body", {
    pluginId: PLUGIN_ID,

    classNameBindings: ["composer.optedOut"],
  });

  api.modifyClass(
    "model:composer",
    (Superclass) =>
      class extends Superclass {
        groupTrackerOptOut(opts) {
          this.set("optedOut", opts.post && opts.post.opted_out);
        }

        open(opts) {
          opts = opts || {};
          return super.open(opts).then(() => this.groupTrackerOptOut(opts));
        }
      }
  );

  api.modifyClass(
    "model:post",
    (Superclass) =>
      class extends Superclass {
        beforeCreate(props) {
          const composerController =
            getOwnerWithFallback(this).lookup("service:composer");

          if (composerController.get("model.optedOut")) {
            props.opted_out = true;
          }
        }
      }
  );

  const site = api.container.lookup("service:site");
  const currentUser = api.container.lookup("service:current-user");
  const composer = api.container.lookup("service:composer");

  api.addComposerToolbarPopupMenuOption({
    action: () => {
      composer.toggleProperty("model.optedOut");
    },
    label: "group_tracker.opt_out.title",
    icon: "link-slash",
    condition: () => {
      const action = composer.model.action;

      if (!site.tracked_groups) {
        return false;
      }

      if (!currentUser) {
        return false;
      }

      if (!currentUser.primary_group_id) {
        return false;
      }

      if (ALLOWED_COMPOSER_ACTIONS.indexOf(action) < 0) {
        return false;
      }

      return (
        site.tracked_groups
          .map((g) => g.id)
          .indexOf(currentUser.primary_group_id) >= 0
      );
    },
  });
}

export default {
  name: "group-tracker",

  initialize() {
    withPluginApi("0.8.9", (api) => {
      modifyTopicModel(api);
      addNavigationBarItems(api);
      addOptOutClassOnPost(api);
      addOptOutToggle(api);
      addTrackedGroupToTopicList(api);
    });
  },
};
