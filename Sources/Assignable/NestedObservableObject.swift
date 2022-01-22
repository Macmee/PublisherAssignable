//
//  NestedObservableObject.swift
//  PublishedViewModels
//
//  Created by David Zorychta on 1/16/22.
//

import Combine
import SwiftUI

// MARK: - NestedObservableObject

open class NestedObservableObject: ObservableObject {

  private var bag = Set<AnyCancellable>()

  init() {
    Mirror(reflecting: self).children.forEach { property in
      if var value = property.value as? DynamicPropertyObserver {
        value
          .objectWillChangeObserver()
          .sink { [weak self] _ in
            self?.objectWillChange.send()
          }
          .store(in: &bag)
      }
    }
  }

}

// MARK: - NestedPropertyObserver

public protocol DynamicPropertyObserver: DynamicProperty {
  mutating func objectWillChangeObserver() -> AnyPublisher<Void, Never>
}

// MARK: - @Published

extension Combine.Published: DynamicPropertyObserver {
  mutating public func objectWillChangeObserver() -> AnyPublisher<Void, Never> {
    projectedValue.map({ _ in () }).eraseToAnyPublisher()
  }
}

// MARK: - @Assignable

extension Assignable: DynamicPropertyObserver {
  mutating public func objectWillChangeObserver() -> AnyPublisher<Void, Never> {
    boxed.objectWillChange.eraseToAnyPublisher()
  }
}
