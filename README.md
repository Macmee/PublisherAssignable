# PublisherAssignable

Often times we want to use a `Publisher` in a SwiftUI view. We write code to do so such as:

```swift
struct SubredditView: View {

  @State var posts: [RedditPost] = []
  
  var body: some View {
    List(posts) {
      PostRow(post: $0)
    }
    .onReceive(getReddit("pics").replaceError(with: [])) { posts in
      self.posts = posts
    }
  }

}
```

This is quite verbose because we have to chain on a View with `.onReceive` to observe our publisher, and then when we get results we have to manually assign them to our state variable `posts`. It is also not ideal because technically anyone from within our View could assign onto `posts`, meaning we have mutable state and potentially multiple paths in our codebase where it may be mutated. This project adds the `@Assignable` property wrapper so that you can instead do:

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

And now instead of having a separate variable `posts` and a publisher `getReddit("pics").replaceError(with: [])` you now simply have a singular dynamic property that is both your publisher and local variable ready to use in SwiftUI.

This is more straight forward and concise to read, and also supports more complex use cases as well. Lets say you were to introduce a `TextField` on your SwiftUI view that allowed your users to change which subreddit they were viewing. You also decide you want to manage your view state in a separate view model:

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
You can imagine building a view model to support this such as:

```swift
class SubredditViewModel: NestedObservableObject {
  
  // MARK: - Inputs
  @Published var subredditInput: String
  
  // MARK: - Outputs
  @Published private(set) var postsOutput: [RedditPost] = []
  
  // MARK: - Privates
  private var bag = Set<AnyCancellable>()
  
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
There are a few important things to note here. Our view model is an observable object with two properties, `subredditInput` and `postsOutput`. As the user types, we bind our `TextField` from our view to `subredditInput`. We observe `subredditInput` in our view model for changes, and then we call `getReddit` to retrieve new reddit posts after a short debounce. This returns a Publisher of `AnyPublisher<[RedditPost, Error]>`. We observe these changes and call into `.assign` to map the resulting posts to our `@Published` property `postsOutput` which our view in turn will render.

Instead of writing our view model this way, this package allows us to do this instead:

```swift
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
      .map(getReddit)
      .switchToLatest()
      .replaceError(with: [])
      .asAssignable()
    super.init()
  }
  
}
```

The important distinction here is that we no longer maintain two separate variables (a publisher and published property) but now instead simply have a singular `@Assignable` property that we assign our publisher directly to after calling `.asAssignable()` on it.

The benefits of this are:

* The code is again more concise because we have removed one aspect of complexity
* The code is safer because the entire functionality taking place may be contained within a single observable chain which does not produce side effects. We don't have to maintain both an observable chain _and_ a separate variable (`posts`) that we manually assign values to after the fact.
* It is guaranteed that another actor outside our block of code cannot change the value of `postsOutput` unaware to us which is not the case with `@Published` (you could assign anywhere to such a variable or at least anywhere within the same class even if you were to annotate it with `private(set)`). For example, this is not allowed:

```swift
class SubredditViewModel: NestedObservableObject {
  
  // ...
  
  func resetPosts() {
    postsOutput = [] // ⛔️ Cannot assign to property: 'postsOutput' is a get-only property
  }
  
}
```

You are instead forced to implement such functionality as part of your observable chain above, thus ensuring logic surrounding the state of `postsOutput` is managed in the same observable chain in one singular spot in your view model. This is good hygene to maintain especially as view models grow and also helpful when debugging so that you only have to trace logic throughout one linear chain of steps as opposed to in various unordered spots throughout your code.

One other interesting thing to note here is that we were able to utilize a custom dynamic property (`@Assignable`) from inside an observed object. SwiftUI generally doesn't allow this functionality outside of `ObservedObject` and `Published` properties. This package introduces a new class `NestedObservableObject` which allows the user to create custom view models with any number of custom dynamic properties. They will all play nicely with SwiftUI so long as the dynamic property conforms to the single-function protocol `DynamicPropertyObserver`.
