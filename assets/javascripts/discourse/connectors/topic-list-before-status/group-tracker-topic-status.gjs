import GroupTrackerTopicStatus from "../../components/group-tracker-topic-status";

const connector = <template>
  <GroupTrackerTopicStatus @topic={{@outletArgs.topic}} />
</template>;

export default connector;
