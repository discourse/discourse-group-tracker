import { withPluginApi } from "discourse/lib/plugin-api";
import { iconNode } from "discourse-common/lib/icon-library";
import computed from "ember-addons/ember-computed-decorators";
import Composer from "discourse/models/composer";
import groupTrackerIcon from "discourse/plugins/discourse-group-tracker/lib/group-tracker-icon";
import DiscourseURL from "discourse/lib/url";

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
  api.modifyClass("component:topic-list-item", {
    @computed("topic.first_tracked_post")
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

  if (!tracked_groups) {
    return;
  }

  tracked_groups
    .filter(g => g.add_to_navigation_bar)
    .forEach(g => {
      let groupId = `group-${g.name}`;
      api.addNavigationBarItem({
        name: groupId,
        displayName: g.full_name,
        title: g.full_name,
        classNames: groupId,
        href: Discourse.getURL(`/g/${g.name}/activity/posts`),
        filterMode: groupId,
        includeCategoryId: true
      });
    });
}

function addControlToTimeline(api) {
  const appEvents = api.container.lookup("app-events:main");
  const topicController = api.container.lookup("controller:topic");

  let currentPostNumber = 1;

  appEvents.on("topic:current-post-changed", ({ post }) => {
    currentPostNumber = post.post_number;
  });

  api.decorateWidget("timeline-controls:before", helper => {
    const { topic } = helper.attrs;
    if (topic.first_tracked_post) {
      return helper.attach("button", {
        className: "first-tracked-post",
        icon: "arrow-circle-up",
        title: "group_tracker.first_post",
        action: "jumpToFirstTrackedPost",
        disabled: topic.first_tracked_post.post_number >= currentPostNumber
      });
    }
  });

  api.reopenWidget("timeline-controls", {
    jumpToFirstTrackedPost() {
      const { topic } = this.attrs;
      if (topic.first_tracked_post) {
        topicController.send(
          "jumpToPost",
          topic.first_tracked_post.post_number
        );
      }
    }
  });

  function getPreviousTrackedPost(topic) {
    const postStream = topic.get("postStream");
    const stream = postStream.get("stream");

    return (
      topic &&
      topic.tracked_posts &&
      topic.tracked_posts
        .filter(p => {
          return (
            p.post_number < currentPostNumber &&
            stream.includes(postStream.findPostIdForPostNumber(p.post_number))
          );
        })
        .pop()
    );
  }

  function getNextTrackedPost(topic) {
    const postStream = topic.get("postStream");
    const stream = postStream.get("stream");

    return (
      topic &&
      topic.tracked_posts &&
      topic.tracked_posts.find(p => {
        return (
          p.post_number > currentPostNumber &&
          stream.includes(postStream.findPostIdForPostNumber(p.post_number))
        );
      })
    );
  }

  api.decorateWidget("timeline-footer-controls:after", helper => {
    const { topic } = helper.attrs;
    const { site, siteSettings } = helper.widget;
    const nextTrackedPost = getNextTrackedPost(topic);
    const prevTrackedPost = getPreviousTrackedPost(topic);
    const group = prevTrackedPost ? prevTrackedPost.group : null;
    const nextGroup = nextTrackedPost ? nextTrackedPost.group : null;

    //if both buttons are disabled, do not display
    if (group === null && nextGroup === null) {
      return null;
    }

    return helper.attach("button", {
      className: "prev-tracked-post",
      icon: groupTrackerIcon(group, site, siteSettings),
      contents: iconNode("arrow-left"),
      title: "group_tracker.prev_post",
      action: "jumpToPrevTrackedPost",
      disabled: group === null
    });
  });

  api.decorateWidget("timeline-footer-controls:after", helper => {
    const { topic } = helper.attrs;
    const { site, siteSettings } = helper.widget;
    const nextTrackedPost = getNextTrackedPost(topic);
    const prevTrackedPost = getPreviousTrackedPost(topic);
    const group = nextTrackedPost ? nextTrackedPost.group : null;
    const prevGroup = prevTrackedPost ? prevTrackedPost.group : null;

    //if both buttons are disabled, do not display
    if (group === null && prevGroup === null) {
      return null;
    }

    return helper.attach("button", {
      className: "next-tracked-post",
      icon: groupTrackerIcon(group, site, siteSettings),
      contents: iconNode("arrow-right"),
      title: "group_tracker.next_post",
      action: "jumpToNextTrackedPost",
      disabled: group === null
    });
  });

  api.reopenWidget("timeline-footer-controls", {
    jumpToNextTrackedPost() {
      const { topic } = this.attrs;
      const nextTrackedPost = getNextTrackedPost(topic);

      if (nextTrackedPost) {
        const url = topic.url + "/" + nextTrackedPost.post_number;
        DiscourseURL.routeTo(url);
      }
    },

    jumpToPrevTrackedPost() {
      const { topic } = this.attrs;
      const prevTrackedPost = getPreviousTrackedPost(topic);

      if (prevTrackedPost) {
        const url = topic.url + "/" + prevTrackedPost.post_number;
        DiscourseURL.routeTo(url);
      }
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
      return (
        this.site.tracked_groups
          .map(g => g.id)
          .indexOf(this.currentUser.primary_group_id) >= 0
      );
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
    condition: "showOptOutToggle"
  }));
}

export default {
  name: "group-tracker",

  initialize() {
    withPluginApi("0.8.9", api => {
      modifyTopicModel(api);

      addNavigationBarItems(api);

      addControlToTimeline(api);

      addOptOutClassOnPost(api);
      addOptOutToggle(api);
      addTrackedGroupToTopicList(api);
    });
  }
};
