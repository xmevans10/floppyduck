import SwiftUI

// MARK: - Data Model

struct PatchEntry: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    let items: [String]
}

struct PatchRelease: Identifiable {
    let id = UUID()
    let version: String
    let date: String
    let entries: [PatchEntry]

    static let current: PatchRelease = PatchRelease(
        version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        date: "May 2026",
        entries: [
            PatchEntry(title: "TESTING", color: GK.Colors.buttonGreen, items: [
                "testing! hi floppies!",
            ]),
        ]
    )
}

// MARK: - Wooden Board Background

struct WoodenBoardBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(GK.Colors.woodSurface)

                Canvas { context, size in
                    let grain = GK.Colors.woodGrain
                    let step: CGFloat = 5
                    var y: CGFloat = 0

                    while y < size.height {
                        let seed = Int(y / step)
                        let variation = CGFloat(((seed * 7) % 5))
                        let startX: CGFloat = variation + 2
                        let lineWidth = size.width - startX - variation - 2
                        let thickness: CGFloat = (seed % 4 == 0) ? 2 : 1.5

                        context.fill(
                            Path(CGRect(x: startX, y: y, width: lineWidth, height: thickness)),
                            with: .color(grain.opacity(0.18))
                        )

                        // Occasional darker double-line
                        if seed % 7 == 0 {
                            context.fill(
                                Path(CGRect(x: startX + 2, y: y + thickness + 1, width: lineWidth - 4, height: 1)),
                                with: .color(grain.opacity(0.10))
                            )
                        }

                        y += step
                    }
                }
            }
        }
    }
}

// MARK: - Nail

struct ParkNailView: View {
    let alignment: Alignment

    private var offset: (x: CGFloat, y: CGFloat) {
        switch alignment {
        case .topLeading:     return (12, 12)
        case .topTrailing:    return (-12, 12)
        case .bottomLeading:  return (12, -12)
        case .bottomTrailing: return (-12, -12)
        default:              return (0, 0)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.35, green: 0.35, blue: 0.35))
                .frame(width: 6, height: 6)

            Circle()
                .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                .frame(width: 3, height: 3)
                .offset(x: 0.5, y: 0.5)
        }
    }
}

// MARK: - Patch Notes Overlay

struct PatchNotesOverlay: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(hasAppeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            boardContent
                .scaleEffect(hasAppeared ? 1 : 0.85)
                .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                hasAppeared = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            hasAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
            onDismiss()
        }
    }

    // MARK: - Board

    private var boardContent: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(PatchRelease.current.entries) { entry in
                        sectionView(entry)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 300)
            .padding(.top, 16)

            gotItButton
                .padding(.top, 18)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.panelBorder, lineWidth: 1.5)
                )
        )
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            WoodenBoardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GK.Colors.panelBorder, lineWidth: 3)
                )
        )
        .overlay(nails)
        .padding(.horizontal, 24)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("WHAT'S NEW")
                .font(.custom(GK.pixelFontName, size: 16))
                .foregroundColor(GK.Colors.panelBorder)
                .shadow(color: GK.Colors.panelBorder.opacity(0.3), radius: 0, x: 2, y: 2)

            Text("v\(PatchRelease.current.version)  •  \(PatchRelease.current.date)")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
        }
        .padding(.bottom, 4)
    }

    // MARK: - Section

    private func sectionView(_ entry: PatchEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(entry.color)
                    .frame(width: 8, height: 8)

                Text(entry.title)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
            }

            ForEach(entry.items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(entry.color)

                    Text(item.uppercased())
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.75))
                        .lineSpacing(2)
                }
                .padding(.leading, 14)
            }
        }
    }

    // MARK: - Got It Button

    private var gotItButton: some View {
        Button(action: dismiss) {
            Text("GOT IT!")
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(GK.Colors.buttonGreen)
                        .shadow(color: GK.Colors.buttonGreen.opacity(0.5), radius: 0, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.3), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nails

    private var nails: some View {
        ZStack {
            ParkNailView(alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            ParkNailView(alignment: .topTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            ParkNailView(alignment: .bottomLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            ParkNailView(alignment: .bottomTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.cyan.opacity(0.3).ignoresSafeArea()
        PatchNotesOverlay(isPresented: .constant(true), onDismiss: {})
    }
}
