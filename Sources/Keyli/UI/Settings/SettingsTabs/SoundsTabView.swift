import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct SoundsTabView: View {
    @ObservedObject private var configStore: ConfigStore = .shared
    @ObservedObject private var soundPacks: SoundPackLibrary = .shared
    @ObservedObject private var catalog: SoundPackCatalog = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Key Sounds", symbol: "speaker.wave.2")

            SettingsToggle(
                "Play keycap sounds",
                detail: "Each key plays its own press and release sound from the chosen sound pack.",
                isOn: $configStore.config.playKeyClickSound
            )

            SettingsRow {
                Text("Sound pack")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 130, alignment: .leading)

                SettingsMenuPicker(
                    "Sound pack",
                    selection: Binding(
                        get: { soundPacks.pack(id: configStore.config.keySoundPackId)?.id ?? configStore.config.keySoundPackId },
                        set: { configStore.config.keySoundPackId = $0 }
                    ),
                    options: soundPacks.packs.map { SettingsMenuOption($0.id, $0.isBundled ? $0.name : "\($0.name) (installed)") }
                )

                Button("Preview") {
                    KeySoundEngine.shared.preview()
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .disabled(!configStore.config.playKeyClickSound)
            }

            SettingsSliderRow(
                "Volume",
                value: $configStore.config.keySoundVolume,
                in: 0...1,
                step: 0.05,
                valueText: "\(Int((configStore.config.keySoundVolume * 100).rounded()))%"
            )

            SettingsToggle(
                "Play sounds for my physical keyboard",
                detail: "Also plays the pack while you type on your Mac's keyboard. Needs Input Monitoring.",
                isOn: $configStore.config.keySoundsForPhysicalTyping
            )

            SettingsRow {
                Button("Import Pack…") {
                    importSoundPack()
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .help("Import a sound pack as a .zip file or a folder that contains config.json")

                if let current = soundPacks.pack(id: configStore.config.keySoundPackId), !current.isBundled {
                    Button("Remove Pack") {
                        removeSoundPack(current)
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle(isDestructive: true))
                }

            }

            if let status = soundPacks.status {
                statusBanner(status)
            }

            SettingsSectionHeader(title: "Browse Packs", symbol: "square.and.arrow.down")

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .accessibilityHidden(true)
                    TextField("Search packs", text: $catalog.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit { catalog.reload() }
                    if !catalog.query.isEmpty {
                        Button {
                            catalog.query = ""
                            catalog.reload()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
                )

                SettingsMenuPicker(
                    "Sort packs",
                    selection: $catalog.sort,
                    options: CatalogSort.allCases.map { SettingsMenuOption($0, $0.title) },
                    width: 170
                )
            }
            .padding(.leading, 33)
            .padding(.trailing, 10)
            .padding(.bottom, 4)

            if let error = catalog.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Retry") { catalog.reload() }
                        .buttonStyle(SettingsSecondaryButtonStyle())
                }
                .padding(.leading, 33)
                .padding(.trailing, 10)
            }

            let installedById = Dictionary(soundPacks.packs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let selectedId = soundPacks.pack(id: configStore.config.keySoundPackId)?.id
            let lastId = catalog.packs.last?.id
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(catalog.packs.enumerated()), id: \.element.id) { index, pack in
                    if index > 0 {
                        Divider()
                            .opacity(0.35)
                            .padding(.leading, 33)
                    }
                    catalogRow(pack, installed: installedById[pack.safeId], selectedId: selectedId)
                        .onAppear {
                            if pack.id == lastId {
                                catalog.loadMore()
                            }
                        }
                }
            }

            HStack {
                Spacer()
                if catalog.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if catalog.hasMore {
                    Button("Load More") { catalog.loadMore() }
                        .buttonStyle(SettingsSecondaryButtonStyle())
                } else if catalog.packs.isEmpty && catalog.errorMessage == nil {
                    Text("No packs found.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
            }
            .padding(.top, 6)

            Text("Community packs and the pack format by Mechvibes (mechvibes.com). Each pack keeps its maker's license.")
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary.opacity(0.8))
                .padding(.leading, 33)
                .padding(.top, 8)
        }
        .onAppear { catalog.loadIfNeeded() }
    }

    private func catalogRow(_ pack: CatalogPack, installed: SoundPackInfo?, selectedId: String?) -> some View {
        let isSelected = installed != nil && selectedId == pack.safeId
        let isInstalling = catalog.installing.contains(pack.id)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(details(for: pack))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            .help(pack.description ?? pack.name)

            Spacer(minLength: 8)

            if isInstalling {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 72)
            } else if isSelected {
                Label("In Use", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 72)
            } else if let installed {
                Button {
                    KeySoundEngine.shared.preview(pack: installed)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Preview “\(pack.name)”")
                .accessibilityLabel("Preview \(pack.name)")

                Button("Use") {
                    configStore.config.keySoundPackId = installed.id
                    if !configStore.config.playKeyClickSound {
                        configStore.config.playKeyClickSound = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        KeySoundEngine.shared.preview()
                    }
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .frame(width: 72)
            } else {
                Button("Install") {
                    catalog.install(pack)
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
                .frame(width: 72)
            }
        }
        .padding(.leading, 33)
        .padding(.trailing, 10)
        .frame(minHeight: 38)
    }

    private func statusBanner(_ status: SoundPackLibrary.ImportStatus) -> some View {
        let isError: Bool
        let message: String
        switch status {
        case .success(let text):
            isError = false
            message = text
        case .failure(let text):
            isError = true
            message = text
        }
        let tint = isError ? Color.red : KeyliChrome.accent
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(isError ? Color.primary : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                soundPacks.status = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 0.5)
        )
        .padding(.leading, 33)
        .padding(.trailing, 10)
        .accessibilityElement(children: .combine)
    }

    private func details(for pack: CatalogPack) -> String {
        var parts: [String] = []
        if let author = pack.author, !author.isEmpty {
            parts.append(author)
        }
        if let rating = pack.ratingAvg, let count = pack.ratingCount, count > 0 {
            parts.append(String(format: "★ %.1f (%d)", rating, count))
        }
        if let downloads = pack.downloads {
            parts.append("\(downloads.formatted()) downloads")
        }
        if let size = pack.zipSize {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        if let license = pack.license, !license.isEmpty {
            parts.append(license)
        }
        return parts.joined(separator: " · ")
    }

    private func importSoundPack() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip, .folder]
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a sound pack .zip file, or a folder that contains config.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let info = try soundPacks.importPack(from: url)
            configStore.config.keySoundPackId = info.id
            soundPacks.status = .success("Imported “\(info.name)”.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                KeySoundEngine.shared.preview()
            }
        } catch {
            soundPacks.status = .failure((error as? LocalizedError)?.errorDescription ?? "Keyli couldn't import that pack: \(error.localizedDescription)")
        }
    }

    private func removeSoundPack(_ info: SoundPackInfo) {
        do {
            try soundPacks.removePack(id: info.id)
            configStore.config.keySoundPackId = SoundPackLibrary.defaultPackId
            soundPacks.status = .success("Removed “\(info.name)”.")
        } catch {
            soundPacks.status = .failure("Keyli couldn't remove “\(info.name)”: \(error.localizedDescription)")
        }
    }
}
