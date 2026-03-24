//
//  AppStarterApp.swift
//  AppStarter
//
//  Created by Fred Strout on 3/24/26.
//

import SwiftUI

@main
struct AppStarterApp: App {
    
  // The container is created once here and passed down via environment.
  @StateObject private var container = DIContainer.shared

  init() {
      // Activate WatchConnectivity early so the session is ready before
      // any view tries to send messages.
      if AppConfiguration.enableWatchSync {
          DIContainer.shared.watchConnectorService.activate()
      }
  }

  var body: some Scene {
      WindowGroup {
          HomeView(viewModel: HomeViewModel(container: container))
              .environmentObject(container)
      }
  }
}
