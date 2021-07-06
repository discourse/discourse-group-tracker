# Group Tracker plugin

Add the ability to quickly find posts of users in a group within topic lists and topics.

### Installation

As seen in a [how-to on meta.discourse.org](https://meta.discourse.org/t/advanced-troubleshooting-with-docker/15927#Example:%20Install%20a%20plugin), simply **add the plugin's repository url to your container's app.yml file**:

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - mkdir -p plugins
          - git clone https://github.com/discourse/discourse-group-tracker.git
```

Rebuild the container

```
cd /var/discourse
git pull
./launcher rebuild app
```

### Configuration

In the "Manage" section of the group you want people to be able to track, enable the
"Track posts made by members of this group" checkbox.

Only users who use this group as their **Primary Group** will be tracked!

In the "Icon used for tracked posts" field, enter the _name_ of a [fontawesome
icon](https://meta.discourse.org/t/101643) that you want to use.
To use your own image, you'll need to
[add a new custom icon by following this guide](https://meta.discourse.org/t/115736).
