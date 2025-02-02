import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if isLoggedIn {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.bar.fill")
                        }
                        .tag(0)
                    
                    AnalyticsView()
                        .tabItem {
                            Label("Analytics", systemImage: "chart.pie.fill")
                        }
                        .tag(1)
                }
                .tint(ThemeColors.accent)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
} 