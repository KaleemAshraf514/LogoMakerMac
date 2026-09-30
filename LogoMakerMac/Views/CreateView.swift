import SwiftUI

struct CreateView: View {
    @State private var selectedOption: String?

    private let options: [(image: String, title: String)] = [
        ("CategoryLogo", "Logo"), ("CategoryPoster", "Poster"),
        ("CategoryIGStory", "IG Story"), ("CategoryInvitation", "Invitation"),
        ("CategoryFlyers", "Flyer"), ("CategoryBusinessCards", "Business Card")
    ]

    private let gridColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(minimum: 140, maximum: 260), spacing: 18),
        count: 3
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("What Would You Like\nTo Create?")
                    .font(.system(size: 34, weight: .bold))
                LazyVGrid(columns: gridColumns, spacing: 18) {
                    ForEach(options, id: \.title) { option in
                        Button { selectedOption = option.title } label: {
                            VStack(spacing: 12) {
                                Image(option.image).resizable().scaledToFit().frame(width: 92, height: 92)
                                Text(option.title).font(.headline).foregroundStyle(AppTheme.primaryText)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 22)
                            .background(RoundedRectangle(cornerRadius: 18).fill(AppTheme.cardBackground))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.separator))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(28)
        }
        .navigationTitle("Create")
        .background(AppTheme.screenBackground)
        .alert("Under Development", isPresented: Binding(
            get: { selectedOption != nil }, set: { if !$0 { selectedOption = nil } }
        )) {
            Button("OK", role: .cancel) { selectedOption = nil }
        } message: { Text("\(selectedOption ?? "This feature") is under development.") }
    }
}
