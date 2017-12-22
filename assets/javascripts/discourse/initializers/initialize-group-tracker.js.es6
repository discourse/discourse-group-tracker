import { withPluginApi } from "discourse/lib/plugin-api";
import { iconNode } from "discourse-common/lib/icon-library";
import computed from "ember-addons/ember-computed-decorators";
import Composer from "discourse/models/composer";
import groupTrackerIcon from "discourse/plugins/discourse-group-tracker/lib/group-tracker-icon";

function modifyTopicModel(api) {
  api.modifyClass("model:topic", {
    // used in the 'topic-list-before-status' connector
    @computed("first_tracked_post.group")
    firstTrackedPostIcon(group) {
      return groupTrackerIcon(group, this.site, this.siteSettings);
    }
  });
}

function addTrackedGroupToTopicList(api) {
  api.modifyClass('component:topic-list-item', {
    @computed('topic.first_tracked_post')
    unboundClassNames(firstTrackedPost) {
      let classNames = this._super();

      if (firstTrackedPost) {
        classNames += ` group-${firstTrackedPost.group}`;
      }

      return classNames;
    }
  });
}

function addNavigationBarItems(api) {
  const { tracked_groups } = api.container.lookup("site:main");

  if (!tracked_groups) { return; }

  tracked_groups
    .filter(g => g.add_to_navigation_bar)
    .forEach(g => {
      let groupId = `group-${g.name}`;
      api.addNavigationBarItem({
        name: g.name,
        displayName: g.full_name,
        title: g.full_name,
        classNames: groupId,
        href: Discourse.getURL(`/groups/${g.name}/activity/posts`),
        filterMode: groupId,
        includeCategoryId: true,
      });
    });
}

function addControlAboveTimeline(api) {
  const topicController = api.container.lookup("controller:topic");

  api.decorateWidget("timeline-controls:before", helper => {
    const { topic } = helper.attrs;
    if (topic.first_tracked_post) {
      return helper.attach("button", {
        className: "first-tracked-post",
        icon: "arrow-circle-up",
        title: "group_tracker.first_post",
        action: "jumpToFirstTrackedPost",
      });
    }
  });

  api.reopenWidget("timeline-controls", {
    jumpToFirstTrackedPost() {
      const { topic } = this.attrs;
      if (topic.first_tracked_post) {
        topicController.send("jumpToPost", topic.first_tracked_post.post_number);
      }
    }
  });
}

function addControlBelowTimeline(api) {
  const appEvents = api.container.lookup("app-events:main");
  const topicController = api.container.lookup("controller:topic");

  let currentPostNumber = 1;

  appEvents.on("topic:current-post-changed", ({ post }) => {
    currentPostNumber = post.post_number;
  });

  function getNextTrackedPost(topic) {
    return topic &&
           topic.tracked_posts &&
           topic.tracked_posts.find(p => p.post_number > currentPostNumber);
  }

  api.decorateWidget("timeline-footer-controls:after", helper => {
    const { topic } = helper.attrs;
    const { site, siteSettings } = helper.widget;
    const nextTrackedPost = getNextTrackedPost(topic);

    if (nextTrackedPost) {
      return helper.attach("button", {
        className: "next-tracked-post",
        icon: groupTrackerIcon(nextTrackedPost.group, site, siteSettings),
        title: "group_tracker.next_post",
        action: "jumpToNextTrackedPost",
      });
    }
  });

  api.reopenWidget("timeline-footer-controls", {
    jumpToNextTrackedPost() {
      const { topic } = this.attrs;
      const nextTrackedPost = getNextTrackedPost(topic);

      if (nextTrackedPost) {
        topicController.send("jumpToPost", nextTrackedPost.post_number);
      }
    }
  });
}

function addNextTrackedPostButton(api) {
  api.includePostAttributes("next_tracked_post");

  let site = api.container.lookup('site:main');
  let insertLoc = site.mobileView ? 'post-avatar:after' : 'post-meta-data:after';
  api.decorateWidget(insertLoc, helper => {
    const { topicUrl, next_tracked_post } = helper.attrs;
    const { siteSettings } = helper.widget;

    if (next_tracked_post) {
      return helper.h(`div.next-tracked-post.group-${next_tracked_post.group}`,
        helper.h("a.tracked-post", {
          attributes: {
            href: Discourse.getURL(`${topicUrl}/${next_tracked_post.post_number}`),
            title: I18n.t("group_tracker.next_group_post", { group: next_tracked_post.group }),
          }
        }, iconNode(groupTrackerIcon(next_tracked_post.group, site, siteSettings)))
      );
    }
  });
}

function addOptOutClassOnPost(api) {
  api.includePostAttributes("opted_out");
  api.addPostClassesCallback(p => p.opted_out && ["opted-out"]);
}

function addOptOutToggle(api) {
  const ALLOWED_COMPOSER_ACTIONS = [Composer.CREATE_TOPIC, Composer.REPLY];

  api.modifyClass("component:composer-body", {
    classNameBindings: ["composer.optedOut"]
  });

  api.modifyClass("model:composer", {
    open(opts) {
      opts = opts || {};
      this._super(opts);
      this.set("optedOut", opts.post && opts.post.opted_out);
    }
  });

  api.modifyClass("controller:composer", {
    @computed("model.action")
    showOptOutToggle(action) {
      if (!this.site.tracked_groups) return false;
      if (!this.currentUser) return false;
      if (!this.currentUser.primary_group_id) return false;
      if (ALLOWED_COMPOSER_ACTIONS.indexOf(action) < 0) return false;
      return this.site.tracked_groups.map(g => g.id).indexOf(this.currentUser.primary_group_id) >= 0;
    },

    actions: {
      togglePostTracking() {
        this.toggleProperty("model.optedOut");
      }
    }
  });

  const composerController = api.container.lookup("controller:composer");

  api.modifyClass("model:post", {
    beforeCreate(props) {
      if (composerController.get("model.optedOut")) {
        props.opted_out = true;
      }
    }
  });

  api.addToolbarPopupMenuOptionsCallback(() => ({
    icon: "unlink",
    label: "group_tracker.opt_out.title",
    action: "togglePostTracking",
    condition: "showOptOutToggle",
  }));
}

export default {
  name: "group-tracker",

  initialize() {
    withPluginApi("0.8.9", api => {
      modifyTopicModel(api);

      addNavigationBarItems(api);

      addControlAboveTimeline(api);
      addControlBelowTimeline(api);

      addNextTrackedPostButton(api);

      addOptOutClassOnPost(api);
      addOptOutToggle(api);
      addTrackedGroupToTopicList(api);
    });
  }
};
