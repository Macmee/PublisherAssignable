//
//  Assignable.swift
//  Shared
//
//  Created by David Zorychta on 1/14/22.
//

import Combine
import SwiftUI

@propertyWrapper
public struct Assignable<T>: DynamicProperty {
  
  final class Box: ObservableObject {
    private var bag = Set<AnyCancellable>()
    @Published var value: T
    init(initialValue: T, upstream: AnyPublisher<T, Never>) {
      value = initialValue
      upstream
        .receive(on: RunLoop.main)
        .sink(receiveValue: { [weak self] newValue in
          self?.value = newValue
        })
        .store(in: &bag)
    }
  }
  
  @ObservedObject private(set) var boxed: Box
  
  public var wrappedValue: T {
    get { boxed.value }
  }
  
  public init<P: Publisher>(wrappedValue: T, _ upstream: P) where P.Output == T, P.Failure == Never {
    let boxed = Box(initialValue: wrappedValue, upstream: upstream.eraseToAnyPublisher())
    _boxed = .init(wrappedValue: boxed)
  }
  
  public init(wrappedValue: T) {
    self.init(wrappedValue: wrappedValue, Empty<T, Never>())
  }
  
}

public extension Publisher where Self.Failure == Never {
  func asAssignable() -> Assignable<Output?> {
    .init(wrappedValue: nil, self.map { Optional<Output>($0) })
  }
  func asAssignable(initialValue: Output) -> Assignable<Output> {
    .init(wrappedValue: initialValue, self)
  }
}
