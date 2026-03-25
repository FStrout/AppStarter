# Project Restructuring Guide: Layer-Based → Feature-Based

## Overview

This guide walks you through migrating your AppStarter project from a flat/layer-based structure to a feature-based architecture that scales better and keeps related files together.

---

## Target Structure

```
AppStarter/
├── App/
│   ├── AppStarterApp.swift
│   └── AppConfiguration.swift
│
├── Features/
│   └── Home/
│       ├── HomeView.swift
│       ├── HomeViewModel.swift
│       └── Components/
│           ├── DeviceInfoSection.swift
│           ├── WatchSyncSection.swift
│           └── UserSection.swift
│
├── Core/
│   ├── Services/
│   │   ├── APIService.swift
│   │   ├── DatabaseService.swift
│   │   ├── DeviceService.swift
│   │   └── WatchConnectorService.swift
│   │
│   ├── Repositories/
│   │   └── UserRepository.swift
│   │
│   ├── Networking/
│   │   ├── APIEndpoint.swift
│   │   └── APIError.swift
│   │
│   └── DI/
│       └── DIContainer.swift
│
├── Shared/
│   ├── Models/
│   │   └── UserModel.swift
│   │
│   └── Extensions/
│       └── (Future extensions)
│
├── Resources/
│   ├── Assets.xcassets
│   └── Documentation/
│       ├── DI-Container-Guide.md
│       └── Project-Restructuring-Guide.md
│
└── Tests/
    ├── Unit/
    │   └── AppStarterTests.swift
    └── UI/
        ├── AppStarterUITests.swift
        └── AppStarterUITestsLaunchTests.swift
```

---

## Migration Steps

### Phase 1: Create the Folder Structure

**Using Xcode Groups (Recommended)**

1. **Select the `AppStarter` folder** in Project Navigator
2. Press **⌘⌥N** to create a new group
3. Create these groups in order:

```
AppStarter
├── App (⌘⌥N, name it "App")
├── Features (⌘⌥N, name it "Features")
├── Core (⌘⌥N, name it "Core")
├── Shared (⌘⌥N, name it "Shared")
├── Resources (⌘⌥N, name it "Resources")
└── Tests (⌘⌥N, name it "Tests")
```

4. **Within Core**, create subgroups:
   - Services
   - Repositories
   - Networking
   - DI

5. **Within Features**, create:
   - Home
   - Home/Components

6. **Within Shared**, create:
   - Models
   - Extensions

7. **Within Tests**, create:
   - Unit
   - UI

8. **Within Resources**, create:
   - Documentation

---

### Phase 2: Move Files (Step by Step)

**Important:** Drag files in Xcode's Project Navigator, don't move them in Finder.

#### Step 1: Move App Files

**Drag these files into `App/` group:**
- `AppStarterApp.swift`
- `AppConfiguration.swift`

✅ **Verify:** Build the project (`⌘B`) to ensure no errors.

---

#### Step 2: Move Core Infrastructure

**Drag these files into `Core/Services/` group:**
- `APIService.swift`
- `DatabaseService.swift`
- `DeviceService.swift`
- `WatchConnectorService.swift`

**Drag these files into `Core/Repositories/` group:**
- `UserRepository.swift`

**Drag these files into `Core/Networking/` group:**
- `APIEndpoint.swift`
- `APIError.swift`

**Drag this file into `Core/DI/` group:**
- `DIContainer.swift`

✅ **Verify:** Build the project (`⌘B`).

---

#### Step 3: Move Shared Models

**Drag these files into `Shared/Models/` group:**
- `UserModel.swift`

✅ **Verify:** Build the project (`⌘B`).

---

#### Step 4: Move Feature Files

**Drag these files into `Features/Home/` group:**
- `HomeView.swift`
- `HomeViewModel.swift`

✅ **Verify:** Build the project (`⌘B`).

---

#### Step 5: Extract Home View Components (Optional but Recommended)

Currently, `HomeView.swift` has three sections as computed properties:
- `deviceSection`
- `watchSection`
- `userSection`

Let's extract these into separate component files for better organization.

**Create `Features/Home/Components/DeviceInfoSection.swift`:**

```swift
// DeviceInfoSection.swift
// StarterApp

import SwiftUI

struct DeviceInfoSection: View {
    let deviceInfo: HomeViewModel.DeviceInfo
    let onRequestPushPermission: () -> Void
    
    var body: some View {
        Section("Device Info") {
            LabeledContent("Device ID", value: deviceInfo.deviceID)
            LabeledContent("Model",     value: deviceInfo.deviceModel)
            LabeledContent("iOS",       value: deviceInfo.osVersion)
            LabeledContent("App",       value: deviceInfo.appVersion)
            LabeledContent("Name",      value: deviceInfo.deviceName)

            Button("Request Push Permission") {
                onRequestPushPermission()
            }
        }
    }
}

#Preview {
    List {
        DeviceInfoSection(
            deviceInfo: HomeViewModel.DeviceInfo(
                deviceID: "ABC-123",
                osVersion: "18.0",
                appVersion: "1.0",
                deviceModel: "iPhone 15 Pro",
                deviceName: "My iPhone"
            ),
            onRequestPushPermission: { print("Request push") }
        )
    }
}
```

**Create `Features/Home/Components/WatchSyncSection.swift`:**

```swift
// WatchSyncSection.swift
// StarterApp

import SwiftUI

struct WatchSyncSection: View {
    let watchState: WatchState
    let hasUser: Bool
    let onPingWatch: () -> Void
    let onSyncUser: () -> Void
    
    var body: some View {
        Section("Apple Watch") {
            LabeledContent("Paired", value: watchState.isPaired ? "Yes" : "No")
            LabeledContent("App Installed", value: watchState.isWatchAppInstalled ? "Yes" : "No")
            LabeledContent("Reachable", value: watchState.isReachable ? "Yes" : "No")

            Button("Ping Watch") {
                onPingWatch()
            }
            .disabled(!watchState.isReachable)

            Button("Sync User to Watch") {
                onSyncUser()
            }
            .disabled(!hasUser || !watchState.isPaired)
        }
    }
}

#Preview {
    List {
        WatchSyncSection(
            watchState: WatchState(
                isPaired: true,
                isWatchAppInstalled: true,
                isReachable: true
            ),
            hasUser: true,
            onPingWatch: { print("Ping") },
            onSyncUser: { print("Sync") }
        )
    }
}
```

**Create `Features/Home/Components/UserSection.swift`:**

```swift
// UserSection.swift
// StarterApp

import SwiftUI

struct UserSection: View {
    let user: UserDTO?
    let isLoading: Bool
    let onCreateUser: () -> Void
    
    var body: some View {
        Section("User (API + Database)") {
            if let user = user {
                LabeledContent("Name",  value: user.name)
                LabeledContent("Email", value: user.email)
                LabeledContent("ID",    value: user.id)
            } else if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading user…").foregroundStyle(.secondary)
                }
            } else {
                Text("No user loaded.").foregroundStyle(.secondary)
            }

            Button("Create Example User") {
                onCreateUser()
            }
        }
    }
}

#Preview {
    List {
        UserSection(
            user: UserDTO(id: "123", name: "Jane Appleseed", email: "jane@example.com"),
            isLoading: false,
            onCreateUser: { print("Create") }
        )
    }
}
```

**Update `Features/Home/HomeView.swift`:**

```swift
// HomeView.swift
// StarterApp
//
// Example SwiftUI view that exercises all four services via HomeViewModel.

import SwiftUI

struct HomeView: View {

    @StateObject var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            List {
                DeviceInfoSection(
                    deviceInfo: viewModel.deviceInfo,
                    onRequestPushPermission: viewModel.requestPushPermission
                )
                
                WatchSyncSection(
                    watchState: viewModel.watchState,
                    hasUser: viewModel.user != nil,
                    onPingWatch: viewModel.pingWatch,
                    onSyncUser: viewModel.syncUserToWatch
                )
                
                UserSection(
                    user: viewModel.user,
                    isLoading: viewModel.isLoading,
                    onCreateUser: {
                        viewModel.createUser(name: "Jane Appleseed", email: "jane@example.com")
                    }
                )
            }
            .navigationTitle("Starter App")
            .toolbar {
                if viewModel.isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                // Load an example user on appear. Replace "user-001" with a
                // real ID from your auth flow or deep link.
                viewModel.loadUser(id: "user-001")
            }
        }
    }
}

// MARK: - Previews

#Preview {
    HomeView(viewModel: HomeViewModel(container: .preview))
}
```

✅ **Verify:** Build and run the app to ensure everything works.

---

#### Step 6: Move Test Files

**Drag these files into `Tests/Unit/` group:**
- `AppStarterTests.swift`

**Drag these files into `Tests/UI/` group:**
- `AppStarterUITests.swift`
- `AppStarterUITestsLaunchTests.swift`

✅ **Verify:** Run tests (`⌘U`) to ensure they still work.

---

#### Step 7: Move Resources

**Drag these into `Resources/` group:**
- `Assets.xcassets`

**Drag documentation files into `Resources/Documentation/` group:**
- `DI-Container-Guide.md`
- `Project-Restructuring-Guide.md` (this file)

✅ **Verify:** Build the project (`⌘B`).

---

#### Step 8: Delete Unused Template Files

**Delete these files** (right-click → Delete → Move to Trash):
- ❌ `ContentView.swift`
- ❌ `Item.swift`

✅ **Verify:** Build the project (`⌘B`).

---

### Phase 3: Verify Everything Works

1. **Build the project:** `⌘B`
   - Should compile with no errors

2. **Run the app:** `⌘R`
   - App should launch normally
   - All features should work

3. **Run tests:** `⌘U`
   - All tests should pass

4. **Check file organization:**
   - All files should be in their proper groups
   - No files should be at the root level (except project files)

---

## Final Project Structure

After migration, your Project Navigator should look like:

```
AppStarter
├── 📁 App
│   ├── AppStarterApp.swift
│   └── AppConfiguration.swift
│
├── 📁 Features
│   └── 📁 Home
│       ├── HomeView.swift
│       ├── HomeViewModel.swift
│       └── 📁 Components
│           ├── DeviceInfoSection.swift
│           ├── WatchSyncSection.swift
│           └── UserSection.swift
│
├── 📁 Core
│   ├── 📁 Services
│   │   ├── APIService.swift
│   │   ├── DatabaseService.swift
│   │   ├── DeviceService.swift
│   │   └── WatchConnectorService.swift
│   ├── 📁 Repositories
│   │   └── UserRepository.swift
│   ├── 📁 Networking
│   │   ├── APIEndpoint.swift
│   │   └── APIError.swift
│   └── 📁 DI
│       └── DIContainer.swift
│
├── 📁 Shared
│   ├── 📁 Models
│   │   └── UserModel.swift
│   └── 📁 Extensions
│       └── (empty for now)
│
├── 📁 Resources
│   ├── Assets.xcassets
│   └── 📁 Documentation
│       ├── DI-Container-Guide.md
│       └── Project-Restructuring-Guide.md
│
└── 📁 Tests
    ├── 📁 Unit
    │   └── AppStarterTests.swift
    └── 📁 UI
        ├── AppStarterUITests.swift
        └── AppStarterUITestsLaunchTests.swift
```

---

## Benefits You'll See Immediately

### 1. **Better Navigation**
- Want to work on Home feature? Everything is in `Features/Home/`
- Need to update API logic? Go to `Core/Services/`
- Looking for the User model? Check `Shared/Models/`

### 2. **Clearer Separation of Concerns**
- **Features**: User-facing functionality
- **Core**: Infrastructure and business logic
- **Shared**: Reusable code across features
- **Resources**: Assets and documentation

### 3. **Easier Onboarding**
- New developers can immediately understand the structure
- Feature boundaries are clear
- Documentation is organized

### 4. **Scalable Architecture**
- Easy to add new features (just create a new folder in `Features/`)
- Infrastructure stays separate from features
- Shared code is explicitly marked

---

## Adding New Features

When you add a new feature in the future, follow this template:

### Example: Adding a "Settings" Feature

1. **Create the feature folder:**
   ```
   Features/Settings/
   ├── SettingsView.swift
   ├── SettingsViewModel.swift
   └── Components/
       ├── AccountSection.swift
       └── PreferencesSection.swift
   ```

2. **Create the View:**
   ```swift
   // SettingsView.swift
   import SwiftUI
   
   struct SettingsView: View {
       @StateObject var viewModel: SettingsViewModel
       
       var body: some View {
           List {
               AccountSection()
               PreferencesSection()
           }
           .navigationTitle("Settings")
       }
   }
   ```

3. **Create the ViewModel:**
   ```swift
   // SettingsViewModel.swift
   import Foundation
   
   @MainActor
   final class SettingsViewModel: ObservableObject {
       
       init(container: DIContainer) {
           // Inject dependencies
       }
   }
   ```

4. **Add navigation from HomeView:**
   ```swift
   .toolbar {
       ToolbarItem {
           NavigationLink {
               SettingsView(viewModel: SettingsViewModel(container: container))
           } label: {
               Image(systemName: "gearshape")
           }
       }
   }
   ```

---

## Troubleshooting

### Build Errors After Moving Files

**Problem:** "Cannot find 'HomeView' in scope"

**Solution:**
1. Make sure the file is included in the target
2. Right-click the file → Show File Inspector
3. Check that your app target is selected under "Target Membership"

---

### Files Showing in Red (Missing)

**Problem:** File references are broken

**Solution:**
1. Delete the red file reference (select it, press Delete, choose "Remove Reference")
2. Drag the file back from Finder into the correct group
3. Ensure target membership is correct

---

### Tests Can't Find App Code

**Problem:** Test files can't import app module

**Solution:**
1. Make sure types are `public` or `internal` (not `private`)
2. Check that test target has correct dependencies
3. For test-only types, use `@testable import AppStarter`

---

## Keyboard Shortcuts Reference

| Action | Shortcut |
|--------|----------|
| New Group | `⌘⌥N` |
| New Group from Selection | `⌘⌥⇧N` |
| Build | `⌘B` |
| Run | `⌘R` |
| Test | `⌘U` |
| Show/Hide Navigator | `⌘0` |
| Show File Inspector | `⌘⌥1` |

---

## Git Commit Strategy

After completing the migration, commit in phases:

### Commit 1: Remove Unused Files
```bash
git rm ContentView.swift Item.swift
git commit -m "Remove unused template files

- ContentView and Item were from Xcode template but not used
- App uses HomeView instead"
```

### Commit 2: Restructure Project
```bash
# Xcode will handle file moves automatically in git
git add .
git commit -m "Restructure project to feature-based architecture

- Organize files into App, Features, Core, Shared, Resources, Tests
- Group Home feature components together
- Separate infrastructure (Services, Repositories, Networking, DI)
- Move shared models to Shared/Models
- Organize test files by type (Unit/UI)
- Move documentation to Resources/Documentation

This structure scales better and keeps related files together."
```

### Commit 3: Extract Home Components (if done)
```bash
git add Features/Home/Components/
git add Features/Home/HomeView.swift
git commit -m "Extract Home view into reusable components

- Create DeviceInfoSection component
- Create WatchSyncSection component  
- Create UserSection component
- Simplify HomeView by using extracted components
- Add previews for each component"
```

---

## Next Steps

After completing this migration:

1. ✅ **Verify everything builds and runs**
2. ✅ **Run all tests to ensure nothing broke**
3. ✅ **Commit your changes with descriptive messages**
4. ✅ **Update your team on the new structure**
5. ✅ **Use this structure for all new features**

### Future Enhancements

Consider these improvements as your app grows:

- **Extract features as Swift Packages** for true module boundaries
- **Add a Shared/Components** folder for reusable UI components
- **Create a Shared/Utilities** folder for helper functions
- **Add feature-specific models** (e.g., `Features/Home/Models/`)
- **Implement a Router** for navigation management

---

## Reference: Before & After

### Before (Flat/Layer-Based)
```
AppStarter/
├── AppStarterApp.swift
├── AppConfiguration.swift
├── HomeView.swift
├── HomeViewModel.swift
├── ContentView.swift (unused)
├── Item.swift (unused)
├── UserModel.swift
├── APIService.swift
├── APIEndpoint.swift
├── APIError.swift
├── DatabaseService.swift
├── DeviceService.swift
├── WatchConnectorService.swift
├── UserRepository.swift
└── DIContainer.swift
```

### After (Feature-Based)
```
AppStarter/
├── App/
├── Features/
│   └── Home/
├── Core/
│   ├── Services/
│   ├── Repositories/
│   ├── Networking/
│   └── DI/
├── Shared/
│   └── Models/
├── Resources/
│   └── Documentation/
└── Tests/
    ├── Unit/
    └── UI/
```

---

## Conclusion

This feature-based structure will:
- ✅ Make your codebase more navigable
- ✅ Scale better as you add features
- ✅ Keep related files together
- ✅ Make it easier to extract modules
- ✅ Improve team collaboration
- ✅ Reduce merge conflicts

**Estimated Migration Time:** 30-45 minutes

**Difficulty:** Easy (just moving files in Xcode)

**Risk:** Very Low (no code changes, just organization)

---

**Happy Coding!** 🚀

**Last Updated:** March 24, 2026  
**Project:** AppStarter
