import SwiftUI

struct ContentView: View {
    @StateObject private var userRepository = UserRepository()

    var body: some View {
        Group {
            if userRepository.hasActiveUser {
                MainTabView()
                    .environmentObject(userRepository)
            } else {
                LoginView()
                    .environmentObject(userRepository)
            }
        }
        .onAppear {
            userRepository.loadCurrentUser()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TimetableView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Timetable")
                }

            InfoCenterView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("Info")
                }

            RoomFinderView()
                .tabItem {
                    Image(systemName: "location")
                    Text("Rooms")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

#Preview {
    ContentView()
}