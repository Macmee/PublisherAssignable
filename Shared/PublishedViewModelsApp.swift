//
//  PublishedViewModelsApp.swift
//  Shared
//
//  Created by David Zorychta on 1/14/22.
//

import Combine
import SwiftUI

@main
struct PublishedViewModelsApp: App {

  var body: some Scene {
    WindowGroup {
      SubredditView(
        viewModel: SubredditViewModel(startingSubreddit: "EarthPorn")
      )
    }
  }
}
