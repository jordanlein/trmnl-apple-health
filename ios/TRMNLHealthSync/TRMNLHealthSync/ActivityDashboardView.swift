import SwiftUI

struct ActivityDashboardView: View {
    @ObservedObject var model: AppModel
    let startSetup: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let snapshot = model.lastSnapshot {
                    SnapshotRingsCard(snapshot: snapshot)
                    SnapshotMetricsGrid(snapshot: snapshot)
                } else {
                    EmptyActivityCard(startSetup: startSetup)
                }

                StatusCard(message: model.statusMessage)

                Button {
                    Task {
                        await model.syncButtonTapped()
                    }
                } label: {
                    if model.isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isBusy || !model.hasConfiguredDestination)
            }
            .padding()
        }
        .navigationTitle("Activity")
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct SnapshotRingsCard: View {
    let snapshot: HealthSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.title2.bold())
                Text("Activity rings from Apple Health")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                RingGauge(
                    title: "Move",
                    value: snapshot.moveKilocalories,
                    goal: snapshot.moveGoalKilocalories,
                    tint: .pink
                )
                RingGauge(
                    title: "Exercise",
                    value: snapshot.exerciseMinutes,
                    goal: snapshot.exerciseGoalMinutes,
                    tint: .green
                )
                RingGauge(
                    title: "Stand",
                    value: snapshot.standHours,
                    goal: snapshot.standGoalHours,
                    tint: .cyan
                )
            }
        }
        .cardStyle()
    }
}

private struct RingGauge: View {
    let title: String
    let value: Int
    let goal: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Gauge(value: Double(value), in: 0...Double(max(goal, 1))) {
                Text(title)
            } currentValueLabel: {
                Text("\(Int(progress * 100))%")
                    .font(.caption2.bold())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)

            Text(title)
                .font(.caption.weight(.semibold))
            Text("\(value) / \(goal)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var progress: Double {
        min(Double(value) / Double(max(goal, 1)), 1)
    }
}

private struct SnapshotMetricsGrid: View {
    let snapshot: HealthSnapshot

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricTile(title: "Steps", value: snapshot.steps.formatted(), systemImage: "figure.walk")
            MetricTile(title: "Distance", value: String(format: "%.2f mi", snapshot.distanceMiles), systemImage: "map")
            MetricTile(title: "Flights", value: snapshot.flightsClimbed.formatted(), systemImage: "stairs")
            MetricTile(title: "Heart Rate", value: "\(snapshot.latestHeartRateBPM) bpm", systemImage: "heart")
            MetricTile(title: "Sleep", value: String(format: "%.1f h", snapshot.sleepHours), systemImage: "bed.double")
            MetricTile(title: "Updated", value: snapshot.capturedAt.formatted(date: .omitted, time: .shortened), systemImage: "clock")
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct EmptyActivityCard: View {
    let startSetup: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundStyle(.pink)

            VStack(spacing: 6) {
                Text("Your rings will appear here")
                    .font(.title3.bold())
                Text("Choose where to send your HealthKit snapshot, connect once, then sync manually or with Shortcuts.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button("Start Setup", action: startSetup)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

private struct StatusCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Sync Status")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

extension View {
    func cardStyle() -> some View {
        padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}
