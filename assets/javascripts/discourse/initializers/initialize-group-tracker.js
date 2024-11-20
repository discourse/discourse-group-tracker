import { withPluginApi } from "discourse/lib/plugin-api";
import Composer from "discourse/models/composer";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import getURL from "discourse-common/lib/get-url";
import computed from "discourse-common/utils/decorators";
import groupTrackerIcon from "discourse/plugins/discourse-group-tracker/lib/group-tracker-icon";

const PLUGIN_ID = "discourse-group-tracker";

function modifyTopicModel(api) {
  api.modifyClass("model:topic", {
    pluginId: PLUGIN_ID,

    // used in the 'topic-list-before-status' connector
    @computed("first_tracked_post.group")
    firstTrackedPostIcon(group) {
      return groupTrackerIcon(group, this.site, this.siteSettings);
    },
  });
}

function addTrackedGroupToTopicList(api) {
  api.modifyClass("component:topic-list-item", {
    pluginId: PLUGIN_ID,

    @computed("topic.first_tracked_post")
    unboundClassNames(firstTrackedPost) {
      let classNames = this._super();

      if (firstTrackedPost) {
        classNames += ` group-${firstTrackedPost.group}`;
      }

      return classNames;
    },
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

  api.modifyClass("model:composer", {
    pluginId: PLUGIN_ID,

    groupTrackerOptOut(opts) {
      this.set("optedOut", opts.post && opts.post.opted_out);
    },
    open(opts) {
      opts = opts || {};
      let promise = this._super(opts);
      // Discourse 2.4.0 sets options directly, 2.5.0 relies on promises
      // TODO: drop the non-promise code once promises are supported in stable
      if (promise) {
        return promise.then(() => this.groupTrackerOptOut(opts));
      }
      this.groupTrackerOptOut(opts);
    },
  });

  api.modifyClass("model:post", {
    pluginId: PLUGIN_ID,

    beforeCreate(props) {
      const composerController =
        getOwnerWithFallback(this).lookup("service:composer");

      if (composerController.get("model.optedOut")) {
        props.opted_out = true;
      }
    },
  });

  const site = api.container.lookup("service:site");
  const currentUser = api.container.lookup("service:current-user");
  const composer = api.container.lookup("service:composer");

  api.addComposerToolbarPopupMenuOption({
    action: () => {
      composer.toggleProperty("model.optedOut");
    },
    label: "group_tracker.opt_out.title",
    icon: "unlink",
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
