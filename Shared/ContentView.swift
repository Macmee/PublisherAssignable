//
//  ContentView.swift
//  Shared
//
//  Created by David Zorychta on 1/14/22.
//

import Combine
import SwiftUI

struct TestModel {
  @Assignable var counter: Int?
}

struct ContentView: View {
  @Assignable var counter: Int?
    var body: some View {
      Text(counter?.description ?? "n/a")
            .padding()
    }
}

@propertyWrapper
struct Assignable<T>: DynamicProperty {
  
  final class Box: ObservableObject {
    private var bag = Set<AnyCancellable>()
    @Published var value: T?
    var test: T?
    init(_ upstream: AnyPublisher<T, Never>) {
      upstream
        .receive(on: RunLoop.main)
        .sink(receiveValue: { [weak self] newValue in
          self?.value = newValue
        })
        .store(in: &bag)
    }
    
    deinit {
      print("VVV goodbye")
    }
  }
  
  @StateObject var boxed: Box
  
  var wrappedValue: T? {
    get { boxed.value }
    set { }
  }
  
  init(_ upstream: AnyPublisher<T, Never>) {
    let boxed = Box(upstream)
    _boxed = .init(wrappedValue: boxed)
  }
  
}

extension Publisher where Self.Failure == Never {
  func asAssignable() -> Assignable<Output> {
    .init(self.eraseToAnyPublisher())
  }
}
