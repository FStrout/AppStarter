# Dependency Injection Container Guide

## What is a DI Container?

A **DI Container** (Dependency Injection Container) is a centralized object that creates, configures, and provides all the dependencies (services, repositories, managers, etc.) that your app needs.

## The Problem It Solves

### Without Dependency Injection ❌

```swift
// Bad: Direct instantiation creates tight coupling
class HomeViewModel {
    let apiService = APIService()
    let database = DatabaseService()
    
    // Problems:
    // 1. Hard to test (can't mock services)
    // 2. Tightly coupled to concrete implementations
    // 3. Can't swap implementations
    // 4. Hidden dependencies
}
```

### With Dependency Injection ✅

```swift
// Good: Dependencies are injected
class HomeViewModel {
    let apiService: APIServiceProtocol
    let database: DatabaseServiceProtocol
    
    init(apiService: APIServiceProtocol, database: DatabaseServiceProtocol) {
        self.apiService = apiService
        self.database = database
    }
    
    // Benefits:
    // 1. Easy to test with mocks
    // 2. Loosely coupled (depends on protocols)
    // 3. Flexible (swap implementations easily)
    // 4. Clear dependencies in the initializer
}
```

## Core Benefits

### 1. **Testability**

Easily swap real services for mocks in tests:

```swift
// Production: Real services
let viewModel = HomeViewModel(container: .shared)

// Testing: Mock services
let viewModel = HomeViewModel(container: .preview)

// Unit Test Example
func testLoadUser() async throws {
    let mockContainer = DIContainer(testing: true)
    let viewModel = HomeViewModel(container: mockContainer)
    
    await viewModel.loadUser(id: "test-123")
    
    #expect(viewModel.user?.id == "test-123")
}
```

### 2. **Single Source of Truth**

All dependencies are created and configured in one place:

```swift
class DIContainer {
    let apiService: APIServiceProtocol
    let databaseService: DatabaseServiceProtocol
    let deviceService: DeviceServiceProtocol
    let watchConnectorService: WatchConnectorServiceProtocol
    
    // Everything is visible and manageable here
}
```

### 3. **Loose Coupling**

Classes depend on protocols, not concrete implementations:

```swift
// ViewModel only knows about the protocol
private let userRepository: UserRepositoryProtocol

// Container decides which implementation to use
lazy var userRepository: UserRepositoryProtocol = UserRepository(...)
// Could easily be: MockUserRepository(...) or CachedUserRepository(...)
```

### 4. **Easy Configuration**

Change implementations globally without touching individual classes:

```swift
// Switch from production to staging by changing one line
convenience init() {
    let api = APIService()
    api.setBaseURL("https://staging-api.example.com")  // Changed once here
    // ... affects entire app
}
```

### 5. **Dependency Graph Management**

The container handles complex dependency chains automatically:

```swift
// UserRepository needs both APIService AND DatabaseService
lazy var userRepository: UserRepositoryProtocol = UserRepository(
    apiService: apiService,           // Container provides this
    databaseService: databaseService  // Container provides this
)

// ViewModels get the fully-configured repository
init(container: DIContainer) {
    self.userRepository = container.userRepository  // Everything wired up
}
```

## Architecture in This Project

### Container Structure

```swift
@MainActor
final class DIContainer: ObservableObject {
    
    // 1. Services (the "leaves" of the dependency tree)
    let apiService: APIServiceProtocol
    let databaseService: DatabaseServiceProtocol
    let deviceService: DeviceServiceProtocol
    let watchConnectorService: WatchConnectorServiceProtocol

    // 2. Repositories (depend on services)
    lazy var userRepository: UserRepositoryProtocol = UserRepository(
        apiService: apiService,
        databaseService: databaseService
    )
    
    // 3. Designated initializer (all dependencies explicit)
    init(
        apiService: APIServiceProtocol,
        databaseService: DatabaseServiceProtocol,
        deviceService: DeviceServiceProtocol,
        watchConnectorService: WatchConnectorServiceProtocol
    ) {
        self.apiService = apiService
        self.databaseService = databaseService
        self.deviceService = deviceService
        self.watchConnectorService = watchConnectorService
    }
}
```

### Production Initialization

```swift
// Creates real services for production use
convenience init() {
    let api = APIService()
    if !AppConfiguration.apiKey.isEmpty {
        api.setGlobalHeader(value: AppConfiguration.apiKey, forKey: "X-API-Key")
    }

    let modelContainer: ModelContainer
    do {
        modelContainer = try ModelContainer.makeAppContainer()
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")
    }

    self.init(
        apiService: api,
        databaseService: DatabaseService(container: modelContainer),
        deviceService: DeviceService(),
        watchConnectorService: WatchConnectorService.shared
    )
}
```

### Testing Initialization

```swift
#if DEBUG
/// Creates a container with mock services for testing
convenience init(testing: Bool) {
    guard testing else {
        self.init()
        return
    }

    let modelContainer: ModelContainer
    do {
        modelContainer = try ModelContainer.makeInMemoryContainer()
    } catch {
        fatalError("Failed to create in-memory ModelContainer: \(error)")
    }

    self.init(
        apiService: MockAPIService(),           // Mock API (no network calls)
        databaseService: DatabaseService(       // In-memory database
            container: modelContainer
        ),
        deviceService: MockDeviceService(),     // Mock device info
        watchConnectorService: MockWatchConnectorService()  // Mock watch
    )
}

static var preview: DIContainer { DIContainer(testing: true) }
#endif
```

## Usage Examples

### In the App Entry Point

```swift
@main
struct AppStarterApp: App {
    @StateObject private var container = DIContainer.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: HomeViewModel(container: container))
                .environmentObject(container)
        }
    }
}
```

### In ViewModels

```swift
@MainActor
final class HomeViewModel: ObservableObject {
    
    private let userRepository: UserRepositoryProtocol
    private let deviceService: DeviceServiceProtocol
    private let watchConnectorService: WatchConnectorServiceProtocol

    init(container: DIContainer) {
        // Get all dependencies from the container
        self.userRepository = container.userRepository
        self.deviceService = container.deviceService
        self.watchConnectorService = container.watchConnectorService
    }
}
```

### In SwiftUI Views

```swift
struct HomeView: View {
    @StateObject var viewModel: HomeViewModel

    var body: some View {
        // ... view code
    }
}

// Production
HomeView(viewModel: HomeViewModel(container: .shared))

// Preview
#Preview {
    HomeView(viewModel: HomeViewModel(container: .preview))
}
```

### In Unit Tests

```swift
import Testing

@Suite("HomeViewModel Tests")
struct HomeViewModelTests {
    
    @Test("Load user successfully")
    func loadUserSuccess() async throws {
        // Arrange
        let container = DIContainer(testing: true)
        let viewModel = HomeViewModel(container: container)
        
        // Act
        await viewModel.loadUser(id: "user-001")
        
        // Assert
        #expect(viewModel.user != nil)
        #expect(viewModel.user?.id == "user-001")
        #expect(viewModel.isLoading == false)
    }
    
    @Test("Handle API error gracefully")
    func loadUserError() async throws {
        // Arrange
        let container = DIContainer(testing: true)
        let viewModel = HomeViewModel(container: container)
        
        // Act
        await viewModel.loadUser(id: "invalid-id")
        
        // Assert
        #expect(viewModel.user == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }
}
```

## Dependency Hierarchy

```
DIContainer
├── Services (Level 1 - No dependencies)
│   ├── APIService
│   ├── DatabaseService
│   ├── DeviceService
│   └── WatchConnectorService
│
├── Repositories (Level 2 - Depend on services)
│   └── UserRepository
│       ├── → APIService
│       └── → DatabaseService
│
└── ViewModels (Level 3 - Depend on repositories & services)
    └── HomeViewModel
        ├── → UserRepository
        ├── → DeviceService
        └── → WatchConnectorService
```

## Best Practices

### ✅ DO

1. **Depend on protocols, not concrete types**
   ```swift
   let apiService: APIServiceProtocol  // ✅ Protocol
   ```

2. **Use the designated initializer for all dependencies**
   ```swift
   init(apiService: APIServiceProtocol, ...)  // ✅ Explicit
   ```

3. **Create convenience initializers for different contexts**
   ```swift
   convenience init() { ... }           // Production
   convenience init(testing: Bool) { ... }  // Testing
   ```

4. **Make services immutable (`let`) when possible**
   ```swift
   let apiService: APIServiceProtocol  // ✅ Immutable
   ```

5. **Use `lazy` for dependencies with complex initialization**
   ```swift
   lazy var userRepository: UserRepositoryProtocol = UserRepository(...)
   ```

### ❌ DON'T

1. **Don't create services directly in ViewModels**
   ```swift
   let apiService = APIService()  // ❌ Tight coupling
   ```

2. **Don't use global singletons everywhere**
   ```swift
   APIService.shared.fetchData()  // ❌ Hard to test
   ```

3. **Don't hide dependencies**
   ```swift
   class ViewModel {
       func loadData() {
           APIService().fetch()  // ❌ Hidden dependency
       }
   }
   ```

4. **Don't make the container do too much**
   ```swift
   // ❌ Container shouldn't have business logic
   func processUserData() { ... }
   ```

## Common Alternatives

### Manual Injection

Pass dependencies individually (verbose for many dependencies):

```swift
init(
    apiService: APIServiceProtocol,
    database: DatabaseServiceProtocol,
    device: DeviceServiceProtocol,
    watch: WatchConnectorServiceProtocol,
    repository: UserRepositoryProtocol
) {
    // Verbose but explicit
}
```

### Service Locator Pattern

Global access to services:

```swift
class ServiceLocator {
    static func getAPIService() -> APIServiceProtocol { ... }
}

// Usage
let api = ServiceLocator.getAPIService()  // Hidden dependency
```

**Downsides:** Harder to test, hides dependencies, global state.

### Third-Party DI Frameworks

- **Swinject** - Feature-rich DI container
- **Needle** - Compile-time safe DI from Uber
- **Factory** - Property wrapper-based DI

**When to use:** Large projects with complex dependency graphs.

**Our approach:** Lightweight, Swift-native container perfect for most iOS apps.

## Extending the Container

### Adding a New Service

1. **Create the protocol:**
   ```swift
   protocol AnalyticsServiceProtocol {
       func track(event: String)
   }
   ```

2. **Create the implementation:**
   ```swift
   class AnalyticsService: AnalyticsServiceProtocol {
       func track(event: String) {
           print("Tracking: \(event)")
       }
   }
   ```

3. **Add to DIContainer:**
   ```swift
   let analyticsService: AnalyticsServiceProtocol
   
   init(
       apiService: APIServiceProtocol,
       // ... other services
       analyticsService: AnalyticsServiceProtocol  // Add here
   ) {
       self.apiService = apiService
       // ...
       self.analyticsService = analyticsService
   }
   ```

4. **Update convenience initializers:**
   ```swift
   convenience init() {
       self.init(
           apiService: APIService(),
           // ...
           analyticsService: AnalyticsService()  // Production
       )
   }
   
   convenience init(testing: Bool) {
       self.init(
           apiService: MockAPIService(),
           // ...
           analyticsService: MockAnalyticsService()  // Testing
       )
   }
   ```

### Adding a New Repository

```swift
// In DIContainer
lazy var postRepository: PostRepositoryProtocol = PostRepository(
    apiService: apiService,
    databaseService: databaseService
)
```

## Summary

The DI Container pattern provides:

- ✅ **Testability** - Easy to mock dependencies
- ✅ **Flexibility** - Swap implementations without code changes
- ✅ **Clarity** - All dependencies in one place
- ✅ **Maintainability** - Changes propagate automatically
- ✅ **Scalability** - Handles complex dependency graphs

This lightweight approach is perfect for iOS apps and doesn't require external dependencies or complex frameworks.

---

**Last Updated:** March 24, 2026  
**Project:** AppStarter
