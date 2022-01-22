//
//  GetReddit.swift
//  TestRxWithSwiftUI
//
//  Created by David Zorychta on 1/4/22.
//

import Combine
import Foundation

struct RedditPost: Decodable, Identifiable {
  let title: String
  let url: String?
  let permalink: String
  let author: String
  let created_utc: Int
  let id: String
}

struct Subreddit: Decodable {
  let kind: String
  let data: SubredditData
}

struct SubredditData: Decodable {
  let children: [SubredditChild]
}

struct SubredditChild: Decodable {
  let data: RedditPost
}

func getReddit(_ subreddit: String) -> AnyPublisher<[RedditPost], Error> {
  let request = URLRequest(url: URL(string: "https://www.reddit.com/r/\(subreddit).json")!)
  return URLSession.shared
    .dataTaskPublisher(for: request)
    .tryMap {
      try JSONDecoder().decode(Subreddit.self, from: $0.data)
    }
    .map { $0.data.children.map { $0.data } }
    .eraseToAnyPublisher()
}
