import SwiftUI

@main
struct LogoMakerMacApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var favourites = FavouritesStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(favourites)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
