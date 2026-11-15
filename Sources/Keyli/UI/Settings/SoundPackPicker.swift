import SwiftUI

final class SoundPackPickerState: ObservableObject {
    @Published var isOpen = false
    @Published var query = ""
}

public struct SoundPackPicker: View {
    @ObservedObject private var configStore: ConfigStore = .shared
    @ObservedObject private var soundPacks: SoundPackLibrary = .shared
    @StateObject private var state = SoundPackPickerState()

    public init() {}

    public static func sections(packs: [SoundPackInfo], favorites: [String], query: String) -> (favorites: [SoundPackInfo], others: [SoundPackInfo]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = trimmed.isEmpty ? packs : packs.filter {
            $0.name.lowercased().contains(trimmed) || ($0.author?.lowercased().contains(trimmed) ?? false)
        }
        let favoriteSet = Set(favorites)
        let favoritePacks = favorites.compactMap { id in matching.first { $0.id == id } }
        return (favoritePacks, matching.filter { !favoriteSet.contains($0.id) })
    }

    public static func cycleOrder(packs: [SoundPackInfo], favorites: [String]) -> [SoundPackInfo] {
        let favoritePacks = favorites.compactMap { id in packs.first { $0.id == id } }
        return favoritePacks.count >= 2 ? favoritePacks : packs
    }

    public static func toggling(_ id: String, in favorites: [String]) -> [String] {
        favorites.contains(id) ? favorites.filter { $0 != id } : favorites + [id]
    }

    private var current: SoundPackInfo? {
        soundPacks.pack(id: configStore.config.keySoundPackId)
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button {
                state.query = ""
                state.isOpen.toggle()
            } label: {
                HStack(spacing: 8) {
                    if let current, configStore.config.favoriteSoundPacks.contains(current.id) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(KeyliChrome.accent)
                            .accessibilityHidden(true)
                    }
                    Text(current?.name ?? "Choose a pack")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 10)
                .frame(width: 220, height: 30)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sound pack")
            .accessibilityValue(current?.name ?? "")
            .popover(isPresented: $state.isOpen, arrowEdge: .bottom) {
                popover
            }

            if let current {
                let isFavorite = configStore.config.favoriteSoundPacks.contains(current.id)
                Button {
                    configStore.config.favoriteSoundPacks = Self.toggling(current.id, in: configStore.config.favoriteSoundPacks)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isFavorite ? KeyliChrome.accent : Color.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Remove from favorites" : "Add to favorites")
                .accessibilityLabel(isFavorite ? "Remove \(current.name) from favorites" : "Add \(current.name) to favorites")
            }
        }
    }

    private var popover: some View {
        let sections = Self.sections(packs: soundPacks.packs, favorites: configStore.config.favoriteSoundPacks, query: state.query)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
                TextField("Search installed packs", text: $state.query)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if !sections.favorites.isEmpty {
                        header("Favorites")
                        ForEach(sections.favorites) { row($0) }
                    }
                    header(sections.favorites.isEmpty ? "Packs" : "All Packs")
                    ForEach(sections.others) { row($0) }
                    if sections.favorites.isEmpty && sections.others.isEmpty {
                        Text("No packs match “\(state.query)”.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary)
                            .padding(8)
                    }
                }
            }
            .frame(height: 300)
        }
        .padding(10)
        .frame(width: 320)
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 6)
            .padding(.top, 6)
    }

    private func row(_ pack: SoundPackInfo) -> some View {
        let selected = pack.id == current?.id
        let favorite = configStore.config.favoriteSoundPacks.contains(pack.id)
        return HStack(spacing: 6) {
            Button {
                configStore.config.keySoundPackId = pack.id
                state.isOpen = false
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(selected ? 1 : 0)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pack.name).font(.system(size: 12, weight: selected ? .semibold : .regular)).lineLimit(1)
                        if let author = pack.author, !author.isEmpty {
                            Text(pack.isBundled ? "\(author) · Built-in" : author)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                KeySoundEngine.shared.preview(pack: pack)
            } label: {
                Image(systemName: "speaker.wave.2").font(.system(size: 10.5))
            }
            .buttonStyle(.plain)
            .help("Preview")
            .accessibilityLabel("Preview \(pack.name)")
            Button {
                configStore.config.favoriteSoundPacks = Self.toggling(pack.id, in: configStore.config.favoriteSoundPacks)
            } label: {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(.system(size: 10.5))
                    .foregroundStyle(favorite ? KeyliChrome.accent : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favorite ? "Remove \(pack.name) from favorites" : "Add \(pack.name) to favorites")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(selected ? KeyliChrome.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
