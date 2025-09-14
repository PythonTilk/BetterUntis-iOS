import SwiftUI

struct ContentView: View {
    @StateObject private var userRepository = UserRepository()
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if userRepository.hasActiveUser {
                MainTabView(selectedTab: $selectedTab)
                    .environmentObject(userRepository)
            } else {
                LoginView()
                    .environmentObject(userRepository)
            }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            TimetableView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Timetable")
                }
                .tag(0)

            InfoCenterView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("Info Center")
                }
                .tag(1)

            RoomFinderView()
                .tabItem {
                    Image(systemName: "location")
                    Text("RoomFinder")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}