//
//  SubredditViewModel.swift
//  PublishedViewModels
//
//  Created by David Zorychta on 1/14/22.
//

import Combine
import Foundation

class SubredditViewModel: ObservableObject {
  
  // MARK: - Inputs
  @Published var subredditInput: String
  
  // MARK: - Outputs
  @Assignable var postsOutput: [RedditPost]?
  
  // MARK: - Privates
  private var bag = Set<AnyCancellable>()
  
  init(startingSubreddit: String) {
    var v = Published(wrappedValue: startingSubreddit)
    _subredditInput = v
    _postsOutput = v
      .projectedValue
      .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
      .prepend(startingSubreddit)
      .map(getReddit)
      .switchToLatest()
      .replaceError(with: [])
      .asAssignable()
    //_postsOutput.boxed.objectWillChange.sink {
    //  self.objectWillChange.send()
    //}.store(in: &bag)
  }
  
}
