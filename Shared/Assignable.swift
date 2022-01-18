//
//  Assignable.swift
//  Shared
//
//  Created by David Zorychta on 1/14/22.
//

import Combine
import SwiftUI

@propertyWrapper
struct Assignable<T>: DynamicProperty {
  
  final class Box: ObservableObject {
    private var bag = Set<AnyCancellable>()
    @Published var value: T?
    init(_ upstream: AnyPublisher<T, Never>) {
      upstream
        .receive(on: RunLoop.main)
        .sink(receiveValue: { [weak self] newValue in
          self?.value = newValue
        })
        .store(in: &bag)
    }
  }
  
  @StateObject var boxed: Box
  
  var wrappedValue: T? {
    get { boxed.value }
    nonmutating set { boxed.value = newValue }
  }
  
  init(_ upstream: AnyPublisher<T, Never>) {
    let boxed = Box(upstream)
    _boxed = .init(wrappedValue: boxed)
  }
  
  init(wrappedValue: T?) {
    let boxed = Box(Empty<T, Never>().eraseToAnyPublisher())
    _boxed = .init(wrappedValue: boxed)
  }
  
}

extension Publisher where Self.Failure == Never {
  func asAssignable() -> Assignable<Output> {
    .init(eraseToAnyPublisher())
  }
}
