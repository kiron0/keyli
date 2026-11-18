import SwiftUI

final class PersonalDictionaryDraft: ObservableObject {
    @Published var text = ""
    @Published var showForgetConfirmation = false
}

public struct PersonalDictionaryEditor: View {
    @ObservedObject private var lexicon: PersonalLexicon = .shared
    @ObservedObject private var configStore: ConfigStore = .shared
    @StateObject private var draft = PersonalDictionaryDraft()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Personal dictionary")
                    .font(.system(size: 12, weight: .medium))
                Text("Names, brands and terms that should always be suggested, spelled the way you add them.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
            }

            HStack(spacing: 8) {
                TextField("Add a word", text: $draft.text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(SettingsSecondaryButtonStyle())
                    .disabled(PersonalLexicon.normalized(draft.text.trimmingCharacters(in: .whitespaces)) == nil)
            }

            if !lexicon.data.customWords.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
                    ForEach(lexicon.data.customWords, id: \.self) { word in
                        HStack(spacing: 4) {
                            Text(word)
                                .font(.system(size: 11.5, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                lexicon.removeCustomWord(word)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(word)")
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                    }
                }
                .frame(maxWidth: 480, alignment: .leading)
            }

            if configStore.config.learnWordsFromTyping || lexicon.learnedWordCount > 0 {
                HStack(spacing: 10) {
                    Button("Forget Learned Words…") {
                        draft.showForgetConfirmation = true
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle(isDestructive: true))
                    .disabled(lexicon.learnedWordCount == 0)

                    Text(lexicon.learnedWordCount == 1 ? "1 word learned" : "\(lexicon.learnedWordCount) words learned")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(.leading, 33)
        .padding(.top, 6)
        .confirmationDialog("Forget the words Keyli learned?", isPresented: $draft.showForgetConfirmation) {
            Button("Forget", role: .destructive) {
                lexicon.forgetLearnedWords()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Learned words and next-word predictions are removed. Your personal dictionary is kept.")
        }
    }

    private func add() {
        if lexicon.addCustomWord(draft.text) {
            draft.text = ""
        }
    }
}
