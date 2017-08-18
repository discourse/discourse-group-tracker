export default function(id, site, siteSettings) {
  const trackedGroups = site && site.tracked_groups;
  const defaultIcon = siteSettings && siteSettings.group_tracker_default_icon;

  let trackedGroupIcon;

  if (trackedGroups) {
    const trackedGroup = trackedGroups.find(g => g.name === id);
    trackedGroupIcon = trackedGroup && trackedGroup.tracked_post_icon;
  }

  const groupTrackerDefaultIcon = defaultIcon && defaultIcon.length > 0 ? defaultIcon : null;

  return trackedGroupIcon || groupTrackerDefaultIcon || id;
};
