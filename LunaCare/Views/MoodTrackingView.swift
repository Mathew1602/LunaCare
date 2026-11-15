//
//  MoodTrackingView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
//  Updated by Fernanda
//  Updated by Xiaoya Zou, following MVVM
//

import SwiftUI


// =============================================================
// Theme
// =============================================================

fileprivate enum MoodTheme {

    // Surfaces (adapt to light / dark mode)
    static let background = Color.dynamic(
        light: .white,
        dark:  Color(red: 0.07, green: 0.07, blue: 0.08)
    )
    static let card = Color.dynamic(
        light: .white,
        dark:  Color(red: 0.13, green: 0.13, blue: 0.14)
    )
    static let field = Color.dynamic(
        light: Color(red: 0.97, green: 0.97, blue: 0.95),
        dark:  Color(red: 0.19, green: 0.19, blue: 0.21)
    )
    static let ink = Color.dynamic(
        light: Color(red: 0.10, green: 0.10, blue: 0.12),
        dark:  Color(red: 0.96, green: 0.96, blue: 0.94)
    )

    // Text that sits on top of a pastel (always dark)
    static let onPastel = Color(red: 0.10, green: 0.10, blue: 0.12)

    // Pastel palette
    static let lime     = Color(red: 0.84, green: 0.94, blue: 0.47)
    static let limeDeep = Color(red: 0.62, green: 0.78, blue: 0.20)
    static let lilac    = Color(red: 0.89, green: 0.78, blue: 0.97)
    static let peach    = Color(red: 1.00, green: 0.84, blue: 0.72)
    static let mint     = Color(red: 0.76, green: 0.91, blue: 0.85)
    static let sky      = Color(red: 0.78, green: 0.86, blue: 0.98)
    static let coral    = Color(red: 1.00, green: 0.68, blue: 0.64)

    /// One pastel per mood, in `Mood.allCases` order
    /// (Ecstatic, Happy, Okay, Sad, Angry).
    private static let moodTints: [Color] = [lime, peach, mint, sky, coral]

    static func tint(for mood: Mood) -> Color {
        guard let index = Array(Mood.allCases).firstIndex(of: mood) else {
            return lilac
        }
        return moodTints[index % moodTints.count]
    }
}


fileprivate extension Color {

    static func dynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}


// =============================================================
// Reusable styling
// =============================================================

fileprivate struct MoodCardStyle: ViewModifier {

    var fill: Color = MoodTheme.card

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(fill)
            )
            .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }
}


fileprivate extension View {

    func moodCard(fill: Color = MoodTheme.card) -> some View {
        modifier(MoodCardStyle(fill: fill))
    }
}


fileprivate struct SectionTitle: View {

    let title: String
    let systemImage: String
    var tint: Color = MoodTheme.lime

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoodTheme.onPastel)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint))

            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(MoodTheme.ink)
        }
    }
}


fileprivate struct DateTile<Content: View>: View {

    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(MoodTheme.onPastel.opacity(0.7))

            content
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(MoodTheme.onPastel)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint)
        )
        // Pastel tiles always use light styling so the picker stays readable
        .environment(\.colorScheme, .light)
    }
}


// =============================================================
// Mood Tracking View
// =============================================================

struct MoodTrackingView: View {

    @EnvironmentObject var auth: AuthViewModel

    @StateObject private var vm = MoodTrackingViewModel()

    @FocusState private var noteFocused: Bool

    @State private var navigateToCalendar = false


    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                header

                moodSection

                dateTimeSection

                noteSection

                saveButton

                privacyNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(MoodTheme.background.ignoresSafeArea())

        .navigationTitle("Mood Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MoodTheme.background, for: .navigationBar)


        // =========================================================
        // Navigate to calendar after successful save
        // =========================================================

        .navigationDestination(isPresented: $navigateToCalendar) {
            MoodCalendarView()
        }


        // =========================================================
        // Save success alert
        // =========================================================

        .alert("Mood Saved", isPresented: $vm.showSavedAlert) {

            Button("View Mood Calendar") {
                navigateToCalendar = true
            }

            Button("Stay Here", role: .cancel) { }

        } message: {
            Text("Your mood journal has been saved successfully.")
        }


        // =========================================================
        // Keyboard toolbar
        // =========================================================

        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    noteFocused = false
                }
            }
        }
    }


    // =========================================================
    // Header
    // =========================================================

    private var header: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(greeting)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)

            Text("How are you feeling?")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(MoodTheme.ink)

            Text("Choose the mood that best describes how you feel right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }


    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning ☀️"
        case 12..<17: return "Good afternoon 🌤️"
        default:      return "Good evening 🌙"
        }
    }


    // =========================================================
    // Mood Picker Card
    // =========================================================

    private var moodSection: some View {

        VStack(alignment: .leading, spacing: 18) {

            HStack {

                SectionTitle(
                    title: "Your Mood",
                    systemImage: "face.smiling",
                    tint: MoodTheme.lime
                )

                Spacer()

                if let mood = vm.selectedMood {

                    Text("\(mood.rawValue) \(mood.label)")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(MoodTheme.onPastel)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(MoodTheme.tint(for: mood))
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }

            MoodPickerGrid(selectedMood: $vm.selectedMood)
        }
        .moodCard()
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: vm.selectedMood)
    }


    // =========================================================
    // Date / Time Tiles
    // =========================================================

    private var dateTimeSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            SectionTitle(
                title: "Date & Time",
                systemImage: "calendar",
                tint: MoodTheme.lilac
            )
            .padding(.leading, 4)

            HStack(spacing: 12) {

                DateTile(
                    title: "Date",
                    systemImage: "calendar",
                    tint: MoodTheme.lime
                ) {
                    DatePicker(
                        "Date",
                        selection: $vm.createdAt,
                        displayedComponents: .date
                    )
                }

                DateTile(
                    title: "Time",
                    systemImage: "clock",
                    tint: MoodTheme.lilac
                ) {
                    DatePicker(
                        "Time",
                        selection: $vm.createdAt,
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
    }


    // =========================================================
    // Note Card
    // =========================================================

    private var noteSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                SectionTitle(
                    title: "Journal Note",
                    systemImage: "square.and.pencil",
                    tint: MoodTheme.peach
                )

                Spacer()

                Text("\(vm.note.count) characters")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(MoodTheme.field))
            }

            NoteBox(
                note: $vm.note,
                focused: _noteFocused
            )
        }
        .moodCard()
    }


    // =========================================================
    // Save Button
    // =========================================================

    private var saveButton: some View {

        Button {

            noteFocused = false

            Task {
                await vm.save(uid: auth.uid)
            }

        } label: {

            HStack(spacing: 10) {

                if vm.loading {

                    ProgressView()
                        .tint(MoodTheme.lime)

                } else {

                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(MoodTheme.onPastel)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(
                                saveDisabled
                                    ? MoodTheme.lime.opacity(0.35)
                                    : MoodTheme.lime
                            )
                        )

                    Text("Save Mood")
                        .font(.system(.headline, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundStyle(
                saveDisabled
                    ? AnyShapeStyle(.secondary)
                    : AnyShapeStyle(MoodTheme.background)
            )
            .background(
                Capsule().fill(
                    saveDisabled ? MoodTheme.field : MoodTheme.ink
                )
            )
            .shadow(
                color: saveDisabled ? .clear : .black.opacity(0.15),
                radius: 10,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .disabled(saveDisabled)
        .padding(.top, 4)
    }


    // =========================================================
    // Privacy Note
    // =========================================================

    private var privacyNote: some View {

        HStack(alignment: .center, spacing: 12) {

            Image(systemName: "lock.shield.fill")
                .font(.subheadline)
                .foregroundStyle(MoodTheme.onPastel)
                .frame(width: 32, height: 32)
                .background(Circle().fill(MoodTheme.lilac))

            Text("Your mood journal is stored securely in your LunaCare health record.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MoodTheme.lilac.opacity(0.3))
        )
    }


    // =========================================================
    // Save button state
    // =========================================================

    private var saveDisabled: Bool {

        vm.loading ||
        (
            vm.selectedMood == nil &&
            vm.note
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        )
    }
}


// =============================================================
// Mood Picker
// =============================================================

struct MoodPickerGrid: View {

    @Binding var selectedMood: Mood?

    @Environment(\.colorScheme) private var colorScheme

    private let columns: [GridItem] =
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)


    var body: some View {

        LazyVGrid(columns: columns, spacing: 14) {

            ForEach(Mood.allCases) { mood in

                let isSelected = selectedMood == mood
                let tint = MoodTheme.tint(for: mood)

                Button {

                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedMood = mood
                    }

                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                } label: {

                    VStack(spacing: 8) {

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                tint.opacity(
                                    isSelected
                                        ? 1
                                        : (colorScheme == .dark ? 0.25 : 0.45)
                                )
                            )
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Text(mood.rawValue)
                                    .font(.system(size: 28))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? MoodTheme.ink : .clear,
                                        lineWidth: 2
                                    )
                            )
                            .scaleEffect(isSelected ? 1.06 : 1)

                        Text(mood.label)
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(isSelected ? .bold : .medium)
                            .foregroundStyle(
                                isSelected
                                    ? AnyShapeStyle(MoodTheme.ink)
                                    : AnyShapeStyle(.secondary)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mood.label)
                .accessibilityAddTraits(
                    isSelected ? [.isButton, .isSelected] : [.isButton]
                )
            }
        }
    }
}


// =============================================================
// Note Box
// =============================================================

struct NoteBox: View {

    @Binding var note: String

    @FocusState var focused: Bool

    var borderColor: Color = .gray.opacity(0.15)


    var body: some View {

        ZStack(alignment: .topLeading) {

            TextEditor(text: $note)
                .frame(minHeight: 130)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(MoodTheme.field)
                .clipShape(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            focused ? MoodTheme.limeDeep : borderColor,
                            lineWidth: focused ? 2 : 1
                        )
                )
                .focused($focused)


            if note.isEmpty {

                Text("Write a short note about how you're feeling...")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 19)
                    .padding(.leading, 15)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: focused)
    }
}


#Preview {

    NavigationStack {
        MoodTrackingView()
            .environmentObject(AuthViewModel())
    }
}
