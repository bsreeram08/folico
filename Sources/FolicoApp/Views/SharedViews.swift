import SwiftUI

struct HeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatusBanner: View {
    let message: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
            Text(message)
            Spacer()
        }
        .padding(12)
        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct EmptyStateView<Actions: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    init(systemImage: String, title: String, message: String, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            actions
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct IconLabel: View {
    let iconId: String

    var body: some View {
        let descriptor = BuiltInIcons.descriptor(for: iconId)
        Label(descriptor.label, systemImage: descriptor.symbolName)
            .labelStyle(.titleAndIcon)
    }
}

struct StatusPill: View {
    let status: FolderPreviewStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch status {
        case .failed: .red
        case .applied: .green
        case .applying: .blue
        case .ignored: .secondary
        case .ready: .primary
        }
    }

    private var background: Color {
        switch status {
        case .failed: .red.opacity(0.12)
        case .applied: .green.opacity(0.12)
        case .applying: .blue.opacity(0.12)
        case .ignored: .secondary.opacity(0.12)
        case .ready: .primary.opacity(0.08)
        }
    }
}

struct FlowLayout: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
