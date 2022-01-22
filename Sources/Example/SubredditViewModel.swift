//
//  SubredditViewModel.swift
//  PublishedViewModels
//
//  Created by David Zorychta on 1/14/22.
//

import Combine
import Foundation

class SubredditViewModel: NestedObservableObject {
  
  // MARK: - Inputs
  @Published var subredditInput: String
  
  // MARK: - Outputs
  @Assignable var postsOutput: [RedditPost]?
  
  // MARK: - Privates
  private var bag = Set<AnyCancellable>()
  
  init(startingSubreddit: String) {
    subredditInput = startingSubreddit
    _postsOutput = _subredditInput
      .projectedValue
      .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
      .prepend(startingSubreddit)
      .removeDuplicates()
      .map(getReddit)
      .switchToLatest()
      .replaceError(with: [])
      .asAssignable()

    super.init()
  }
  
}
