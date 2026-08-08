function transform(input) {
  return {
    profile_name: input.profile_name,
    device_name: input.device_name,
    captured_at: input.captured_at,
    sync_time_label: input.sync_time_label,
    date_label: input.date_label,
    snapshot_status: input.snapshot_status || "fresh",
    rings: input.rings || {},
    activity: input.activity || {},
    health: input.health || {},
  };
}
