# PublisherAssignable

Often times with SwiftUI, we find ourselves trying to plug a `Publisher` into a SwiftUI view, like so:

```swift
struct SubredditView: View {

  @State var posts: [RedditPost] = []
  
  var body: some View {
    List(posts) {
      PostRow(post: $0)
    }
    // aka .onReceive(<publisher that fetches reddit posts>)
    .onReceive(getReddit("pics").replaceError(with: [])) { posts in
      self.posts = posts
    }
  }

}
```

And this works great! I think it reads as *slightly* verbose though because we have to chain off of a SwiftUI View to first observe our publisher, and then to relay new values it emits back to our state variable so the view updates itself.

Another (slightly more hidden) problem with the above example is that you can write to `self.posts` from anywhere! Perhaps we have a much larger view, or perhaps we pass `$posts` down to children views and in either case we now have to consider that our state may be mutated in multiple different spots. This is far from ideal because it makes code harder to trace and debug, and often it doesn’t give other developers a clear indication of where to implement changes and additional functionality because your state management is spread out.

As an alternative, this package creates a new  `DynamicProperty` that you can use in SwiftUI to help manage your observable state in a different way:

```swift
struct SubredditView: View {

  @Assignable(getReddit("pics").replaceError(with: [])) var posts: [RedditPost] = []
  
  var body: some View {
    List(posts) {
      PostRow(post: $0)
    }
  }

}
```

In this scenario, instead of having a separate variable `posts` and a publisher `getReddit("pics").replaceError(with: [])` you simply have a singular dynamic property that is both your publisher and local variable!

This is more straight forward and concise to read, and because it eliminates a separate `@State var posts`variable, we no longer have to worry about  our state being mutated in different parts of our codebase. The only place our new `@Assignable var posts` is allowed to be mutated is in the `Publisher` we’ve passed to it. Attempting something like this:

```swift
struct SubredditView: View {

  @Assignable(getReddit("pics").replaceError(with: [])) var posts: [RedditPost] = []
  
  ...

  func sneakyMutatingFunction() {
    posts = []
  }

}
```

Won’t compile `Cannot assign to property: 'posts' is a get-only property`. This is because the `@Assignable` property wrapper intentionally does’t provide a setter for its `wrappedValue`. In other words: your stateful variable is protected from mutations outside of the `Publisher` initially passed to it.

`@Assignable` also supports more complex use cases. Lets say you were to introduce a `TextField` on your SwiftUI view that allowed your users to change which subreddit they were viewing. You also decide you want to manage your view state in a separate view model:

```swift
struct SubredditView: View {
  
  private enum Constant {
    static let titlePrefix = "/r/"
    static let titlePlaceholder = "Subreddit"
    static let titleBackground = Color(red: 43/255, green: 53/255, blue: 53/255)
  }

  @ObservedObject var viewModel: SubredditViewModel
  
  init(viewModel: SubredditViewModel) {
    self.viewModel = viewModel
  }
  
  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 0) {
        Spacer()
        Text(Constant.titlePrefix).foregroundColor(.white)
        TextField(Constant.titlePlaceholder, text: $viewModel.subredditInput)
          .foregroundColor(.white)
          .frame(maxWidth: 100)
        Spacer()
      }.frame(minHeight: 40)
        .background(Constant.titleBackground)
      List(viewModel.postsOutput ?? []) {
        PostRow(post: $0)
      }
    }
  }
}
```

Without `@Assignable`, you can imagine building a view model to support this such as:

```swift
class SubredditViewModel: ObservedObject {
  
  // MARK: - Inputs
  @Published var subredditInput: String
  
  // MARK: - Outputs
  @Published private(set) var postsOutput: [RedditPost] = []
  
  init(startingSubreddit: String) {
    subredditInput = startingSubreddit
    super.init()
    _subredditInput
      .projectedValue
      .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
      .prepend(startingSubreddit)
      .map(getReddit)
      .switchToLatest()
      .replaceError(with: [])
      .assign(to: &$postsOutput)
  }
  
}
```

There are a few important things to note here. Our view model is an observable object with two properties:

* `subredditInput`: We bind this to the subreddit `TextField` in our view. When the user types in a new subreddit, the value of this variable will update live.
* `postsOutput`: When the value of the above subreddit changes, our view model detects the change, fetches new posts from reddit, and assigns these new posts to `postsOutput`.

*(note: to make our reddit client feel smoother, we also debounce the value of `subredditInput` by `1` second, this way our publisher only fires when the user stops typing.)*

Instead of building our view model this way, `@Assignable` lets us write this:

```swift
class SubredditViewModel: NestedObservableObject {
  
  // MARK: - Inputs
  @Published var subredditInput: String
  
  // MARK: - Outputs
  @Assignable var postsOutput: [RedditPost]?
  
  init(startingSubreddit: String) {
    subredditInput = startingSubreddit
    _postsOutput = _subredditInput
      .projectedValue
      .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
      .prepend(startingSubreddit)
      .map(getReddit)
      .switchToLatest()
      .replaceError(with: [])
      .asAssignable()
    super.init()
  }
  
}
```

The important distinction here is that we no longer maintain two separate things (a publisher and published property) to support fetching and storing posts, but now instead simply have a singular `@Assignable` property that we assign our publisher directly to after calling `.asAssignable()` on it.

More benefits include:

* The code is highly concise, `postsOutput` is created and then assigned in one spot only. We don't have to maintain both an observable chain _and_ a separate variable (`posts`).
* The code is safer than in the previous example without `@Assignable` because all mutations to `postsOutput` now take place in a single observable chain in one spot only in our view model.

The second point is especially important— If we had a `@Published var postsOutput` property instead, anyone from within our viewModel (or perhaps even outside of it if we forgot to use `private(set)`) could change the value of `postsOutput`. This package instead enforces that `postsOutput` *must* be defined one time only. For example, if you were to attempt to change the value of `postsOutput` outside of our observable chain you would encounter this:

```swift
class SubredditViewModel: NestedObservableObject {
  
  // ...
  
  func resetPosts() {
    postsOutput = [] // ⛔️ Cannot assign to property: 'postsOutput' is a get-only property
  }
  
}
```

The only way to change the value of `postsOutput` is through our publisher, which is exactly how it should be!

# Dynamic Property Support in View Models
One other interesting thing to note here is that we were able to utilize a custom dynamic property (`@Assignable`) from inside an observed object. 

SwiftUI doesn’t actually allow this out of the box! Custom dynamic properties such as `@Assignable` typically only work inside of SwiftUI views directly. The one exception to this is that `ObservableObject` classes may have `@Published` properties. If you were to add a `@CustomProperty` property to your class, then it would not cause your SwiftUI views to re-render when you change it.

This package introduces a new class `NestedObservableObject` which allows the user to create custom view models with any number of custom dynamic properties. They will all play nicely with SwiftUI so long as the dynamic property conforms to the single-function protocol `DynamicPropertyObserver`. In the above example you can see `NestedObservableObject` at work with `@Assignable`, which conforms to our protocol:

```swift
extension Assignable: DynamicPropertyObserver {
  mutating func objectWillChangeObserver() -> AnyPublisher<Void, Never> {
    boxed.objectWillChange.eraseToAnyPublisher()
  }
}
```
