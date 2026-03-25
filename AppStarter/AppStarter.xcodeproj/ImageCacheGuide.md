# Image Caching Implementation Guide

## Overview

This guide provides a complete implementation of image caching for your AppStarter project using Kingfisher, the industry-standard image caching library for iOS.

---

## Table of Contents

1. [Installation](#installation)
2. [Core Implementation](#core-implementation)
3. [Reusable Components](#reusable-components)
4. [Integration with DIContainer](#integration-with-dicontainer)
5. [Advanced Features](#advanced-features)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Installation

### Using Swift Package Manager (Recommended)

1. **In Xcode, go to:** `File` → `Add Package Dependencies...`
2. **Enter the URL:** `https://github.com/onevcat/Kingfisher.git`
3. **Version:** Select "Up to Next Major Version" with `7.0.0`
4. **Click:** "Add Package"
5. **Select:** Your app target and click "Add Package"

### Manual Package.swift (if using SPM directly)

```swift
dependencies: [
    .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")
]
```

---

## Core Implementation

### 1. Create the Image Cache Service

**File Location:** `Core/Services/ImageCacheService.swift`

```swift
// ImageCacheService.swift
// AppStarter
//
// Centralized image caching service using Kingfisher.
// Handles cache configuration, prefetching, and cache management.

import Foundation
import Kingfisher
import UIKit

protocol ImageCacheServiceProtocol {
    func configure()
    func prefetch(urls: [URL])
    func clearCache()
    func clearMemoryCache()
    func getCacheSize() async -> UInt
}

final class ImageCacheService: ImageCacheServiceProtocol {
    
    // MARK: - Configuration
    
    func configure() {
        configureMemoryCache()
        configureDiskCache()
        configureDownloader()
        setupMemoryWarningHandler()
    }
    
    private func configureMemoryCache() {
        let cache = ImageCache.default
        
        // Memory cache: 300 MB
        cache.memoryStorage.config.totalCostLimit = 300 * 1024 * 1024
        
        // Clean expired images when memory cache is full
        cache.memoryStorage.config.cleanInterval = 120  // 2 minutes
    }
    
    private func configureDiskCache() {
        let cache = ImageCache.default
        
        // Disk cache: 1 GB
        cache.diskStorage.config.sizeLimit = 1000 * 1024 * 1024
        
        // Expire images after 7 days
        cache.diskStorage.config.expiration = .days(7)
        
        // Custom cache path
        cache.diskStorage.config.pathExtension = "app_images"
    }
    
    private func configureDownloader() {
        let downloader = ImageDownloader.default
        
        // Set timeout
        downloader.downloadTimeout = 15.0
        
        // Set max concurrent downloads
        downloader.maxConcurrentDownloads = 6
        
        // Use URLCache as well for double caching
        let urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,  // 50 MB
            diskCapacity: 200 * 1024 * 1024     // 200 MB
        )
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.urlCache = urlCache
        downloader.sessionConfiguration = sessionConfig
    }
    
    private func setupMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearMemoryCache()
        }
    }
    
    // MARK: - Prefetching
    
    func prefetch(urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        let prefetcher = ImagePrefetcher(urls: urls) { skippedResources, failedResources, completedResources in
            print("Prefetch completed: \(completedResources.count) succeeded, \(failedResources.count) failed")
        }
        
        prefetcher.start()
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        ImageCache.default.clearCache {
            print("Image cache cleared")
        }
    }
    
    func clearMemoryCache() {
        ImageCache.default.clearMemoryCache()
        print("Memory cache cleared")
    }
    
    func getCacheSize() async -> UInt {
        await withCheckedContinuation { continuation in
            ImageCache.default.calculateDiskStorageSize { result in
                switch result {
                case .success(let size):
                    continuation.resume(returning: size)
                case .failure:
                    continuation.resume(returning: 0)
                }
            }
        }
    }
}

// MARK: - Mock Implementation

#if DEBUG
final class MockImageCacheService: ImageCacheServiceProtocol {
    func configure() {
        print("[Mock] Image cache configured")
    }
    
    func prefetch(urls: [URL]) {
        print("[Mock] Prefetching \(urls.count) images")
    }
    
    func clearCache() {
        print("[Mock] Cache cleared")
    }
    
    func clearMemoryCache() {
        print("[Mock] Memory cache cleared")
    }
    
    func getCacheSize() async -> UInt {
        return 1024 * 1024 * 50  // Mock 50 MB
    }
}
#endif
```

---

### 2. Integrate with DIContainer

**Update:** `Core/DI/DIContainer.swift`

```swift
// Add to DIContainer.swift

@MainActor
final class DIContainer: ObservableObject {
    
    // ... existing properties
    
    // MARK: - Services
    
    let imageCacheService: ImageCacheServiceProtocol
    
    // MARK: - Designated Init
    
    init(
        apiService: APIServiceProtocol,
        databaseService: DatabaseServiceProtocol,
        deviceService: DeviceServiceProtocol,
        watchConnectorService: WatchConnectorServiceProtocol,
        imageCacheService: ImageCacheServiceProtocol  // Add this
    ) {
        self.apiService = apiService
        self.databaseService = databaseService
        self.deviceService = deviceService
        self.watchConnectorService = watchConnectorService
        self.imageCacheService = imageCacheService  // Add this
        
        // Configure image cache on init
        imageCacheService.configure()
    }
    
    // MARK: - Init (production)
    
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
            watchConnectorService: WatchConnectorService.shared,
            imageCacheService: ImageCacheService()  // Add this
        )
    }
    
    // MARK: - Init (unit tests / previews)
    
    #if DEBUG
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
            apiService: MockAPIService(),
            databaseService: DatabaseService(container: modelContainer),
            deviceService: MockDeviceService(),
            watchConnectorService: MockWatchConnectorService(),
            imageCacheService: MockImageCacheService()  // Add this
        )
    }
    #endif
}
```

---

## Reusable Components

### 1. Basic Cached Image Component

**File Location:** `Shared/Components/CachedAsyncImage.swift`

```swift
// CachedAsyncImage.swift
// AppStarter
//
// A SwiftUI wrapper around Kingfisher for cached image loading.

import SwiftUI
import Kingfisher

struct CachedAsyncImage: View {
    let url: URL?
    let width: CGFloat?
    let height: CGFloat?
    let contentMode: ContentMode
    
    init(
        url: URL?,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        contentMode: ContentMode = .fill
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.contentMode = contentMode
    }
    
    var body: some View {
        KFImage(url)
            .placeholder {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .retry(maxCount: 3, interval: .seconds(5))
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .if(width != nil && height != nil) { view in
                view.frame(width: width, height: height)
            }
            .clipped()
    }
}

// MARK: - View Extension for Conditional Modifiers

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Previews

#Preview("Square Image") {
    CachedAsyncImage(
        url: URL(string: "https://picsum.photos/200"),
        width: 200,
        height: 200
    )
}

#Preview("Circle Avatar") {
    CachedAsyncImage(
        url: URL(string: "https://picsum.photos/100"),
        width: 100,
        height: 100
    )
    .clipShape(Circle())
}
```

---

### 2. Avatar Component

**File Location:** `Shared/Components/AvatarView.swift`

```swift
// AvatarView.swift
// AppStarter
//
// A reusable avatar component with cached image loading.

import SwiftUI
import Kingfisher

struct AvatarView: View {
    let imageURL: URL?
    let size: CGFloat
    let fallbackIcon: String
    
    init(
        imageURL: URL?,
        size: CGFloat = 40,
        fallbackIcon: String = "person.crop.circle.fill"
    ) {
        self.imageURL = imageURL
        self.size = size
        self.fallbackIcon = fallbackIcon
    }
    
    var body: some View {
        KFImage(imageURL)
            .placeholder {
                Image(systemName: fallbackIcon)
                    .resizable()
                    .foregroundStyle(.gray)
            }
            .onFailure { error in
                print("Avatar load failed: \(error.localizedDescription)")
            }
            .retry(maxCount: 3, interval: .seconds(3))
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Previews

#Preview("Small Avatar") {
    AvatarView(
        imageURL: URL(string: "https://picsum.photos/100"),
        size: 40
    )
}

#Preview("Large Avatar") {
    AvatarView(
        imageURL: URL(string: "https://picsum.photos/200"),
        size: 100
    )
}

#Preview("Failed Avatar") {
    AvatarView(
        imageURL: URL(string: "https://invalid-url.com/image.jpg"),
        size: 60
    )
}
```

---

### 3. Advanced Cached Image with Custom States

**File Location:** `Shared/Components/AdvancedCachedImage.swift`

```swift
// AdvancedCachedImage.swift
// AppStarter
//
// An advanced cached image component with custom loading, error, and success states.

import SwiftUI
import Kingfisher

struct AdvancedCachedImage<Placeholder: View, ErrorView: View>: View {
    let url: URL?
    let width: CGFloat?
    let height: CGFloat?
    let contentMode: ContentMode
    let downsampling: CGSize?
    
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let errorView: () -> ErrorView
    
    init(
        url: URL?,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        contentMode: ContentMode = .fill,
        downsampling: CGSize? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder errorView: @escaping () -> ErrorView
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.contentMode = contentMode
        self.downsampling = downsampling
        self.placeholder = placeholder
        self.errorView = errorView
    }
    
    var body: some View {
        KFImage(url)
            .placeholder { placeholder() }
            .onFailure { _ in errorView() }
            .retry(maxCount: 3, interval: .seconds(5))
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .if(downsampling != nil) { view in
                view.downsampling(size: downsampling!)
            }
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .if(width != nil && height != nil) { view in
                view.frame(width: width, height: height)
            }
            .clipped()
    }
}

// MARK: - Convenience Extensions

extension AdvancedCachedImage where Placeholder == ProgressView<EmptyView, EmptyView>, ErrorView == Image {
    init(
        url: URL?,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        contentMode: ContentMode = .fill,
        downsampling: CGSize? = nil
    ) {
        self.init(
            url: url,
            width: width,
            height: height,
            contentMode: contentMode,
            downsampling: downsampling,
            placeholder: { ProgressView() },
            errorView: { Image(systemName: "photo") }
        )
    }
}

// MARK: - Previews

#Preview("Custom Placeholder") {
    AdvancedCachedImage(
        url: URL(string: "https://picsum.photos/300"),
        width: 300,
        height: 200,
        downsampling: CGSize(width: 300, height: 200),
        placeholder: {
            ZStack {
                Color.gray.opacity(0.2)
                ProgressView()
            }
        },
        errorView: {
            ZStack {
                Color.red.opacity(0.1)
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
    )
    .cornerRadius(12)
}
```

---

## Advanced Features

### 1. Image Prefetching

**Example: Prefetch User Avatars**

```swift
// In your ViewModel

@MainActor
final class UserListViewModel: ObservableObject {
    @Published private(set) var users: [UserDTO] = []
    
    private let userRepository: UserRepositoryProtocol
    private let imageCacheService: ImageCacheServiceProtocol
    
    init(container: DIContainer) {
        self.userRepository = container.userRepository
        self.imageCacheService = container.imageCacheService
    }
    
    func loadUsers() async {
        do {
            users = try await userRepository.getAllUsers()
            
            // Prefetch all avatar images
            let avatarURLs = users.compactMap { user in
                URL(string: user.avatarURL)
            }
            imageCacheService.prefetch(urls: avatarURLs)
            
        } catch {
            print("Failed to load users: \(error)")
        }
    }
}
```

---

### 2. Cache Management in Settings

**File Location:** `Features/Settings/CacheSettingsView.swift`

```swift
// CacheSettingsView.swift
// AppStarter
//
// Settings view for managing image cache.

import SwiftUI

struct CacheSettingsView: View {
    @State private var cacheSize: String = "Calculating..."
    @State private var showClearConfirmation = false
    
    let imageCacheService: ImageCacheServiceProtocol
    
    var body: some View {
        List {
            Section("Cache Information") {
                LabeledContent("Cache Size", value: cacheSize)
                
                Button("Refresh Size") {
                    Task {
                        await updateCacheSize()
                    }
                }
            }
            
            Section {
                Button("Clear Memory Cache") {
                    imageCacheService.clearMemoryCache()
                }
                
                Button("Clear All Cache", role: .destructive) {
                    showClearConfirmation = true
                }
            } header: {
                Text("Cache Management")
            } footer: {
                Text("Clearing cache will remove all downloaded images. They will be re-downloaded when needed.")
            }
        }
        .navigationTitle("Image Cache")
        .task {
            await updateCacheSize()
        }
        .confirmationDialog(
            "Clear all cached images?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                imageCacheService.clearCache()
                Task {
                    await updateCacheSize()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private func updateCacheSize() async {
        let size = await imageCacheService.getCacheSize()
        cacheSize = formatBytes(size)
    }
    
    private func formatBytes(_ bytes: UInt) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    NavigationStack {
        CacheSettingsView(imageCacheService: MockImageCacheService())
    }
}
```

---

### 3. Background Image Processing

**Example: Resize and Compress Images**

```swift
import Kingfisher

extension KFImage {
    func optimized(for size: CGSize) -> some View {
        self
            .downsampling(size: size)
            .cacheOriginalImage(false)  // Don't cache original
            .cacheMemoryOnly()          // Only memory cache for processed
    }
}

// Usage
KFImage(url)
    .optimized(for: CGSize(width: 200, height: 200))
    .resizable()
    .frame(width: 200, height: 200)
```

---

## Best Practices

### 1. **Always Use Downsampling for Large Images**

```swift
// ❌ Bad: Loads full image into memory
KFImage(url)
    .resizable()
    .frame(width: 100, height: 100)

// ✅ Good: Downsamples to save memory
KFImage(url)
    .downsampling(size: CGSize(width: 100, height: 100))
    .resizable()
    .frame(width: 100, height: 100)
```

### 2. **Prefetch Images in Lists**

```swift
// Prefetch images when user is about to see them
LazyVStack {
    ForEach(users) { user in
        UserRow(user: user)
    }
}
.onAppear {
    let urls = users.compactMap { URL(string: $0.avatarURL) }
    imageCacheService.prefetch(urls: urls)
}
```

### 3. **Handle Memory Warnings**

Kingfisher automatically handles memory warnings, but you can also manually clear:

```swift
// In your app delegate or scene delegate
func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    ImageCache.default.clearMemoryCache()
}
```

### 4. **Set Appropriate Cache Limits**

```swift
// For apps with many images
cache.memoryStorage.config.totalCostLimit = 500 * 1024 * 1024  // 500 MB
cache.diskStorage.config.sizeLimit = 2000 * 1024 * 1024         // 2 GB

// For apps with few images
cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024  // 100 MB
cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024          // 500 MB
```

### 5. **Use Secure URLs**

```swift
// Always prefer HTTPS
let url = URL(string: "https://example.com/image.jpg")  // ✅
let url = URL(string: "http://example.com/image.jpg")   // ❌
```

---

## Troubleshooting

### Issue: Images Not Loading

**Solution:**
1. Check that the URL is valid and accessible
2. Verify network permissions in Info.plist (for HTTP URLs)
3. Check console for error messages
4. Try clearing cache

### Issue: High Memory Usage

**Solution:**
1. Use downsampling for large images
2. Reduce memory cache limit
3. Use `cacheMemoryOnly()` for temporary images
4. Clear memory cache more frequently

### Issue: Slow Image Loading

**Solution:**
1. Increase `maxConcurrentDownloads`
2. Use prefetching for lists
3. Ensure images are appropriately sized on server
4. Check network connection

### Issue: Cache Growing Too Large

**Solution:**
1. Reduce disk cache size limit
2. Set shorter expiration time
3. Manually clear cache periodically
4. Don't cache very large images

---

## Testing

### Unit Test Example

```swift
import Testing
import Kingfisher

@Suite("Image Cache Tests")
struct ImageCacheTests {
    
    @Test("Cache service configures successfully")
    func configureCache() async throws {
        let service = ImageCacheService()
        service.configure()
        
        // Verify cache is configured
        let cache = ImageCache.default
        #expect(cache.memoryStorage.config.totalCostLimit > 0)
        #expect(cache.diskStorage.config.sizeLimit > 0)
    }
    
    @Test("Prefetch images")
    func prefetchImages() async throws {
        let service = ImageCacheService()
        let urls = [
            URL(string: "https://picsum.photos/100")!,
            URL(string: "https://picsum.photos/200")!
        ]
        
        service.prefetch(urls: urls)
        
        // Wait for prefetch to complete
        try await Task.sleep(for: .seconds(2))
        
        // Images should be in cache
        let size = await service.getCacheSize()
        #expect(size > 0)
    }
}
```

---

## Summary

This implementation provides:

✅ **Automatic caching** - Memory and disk caching out of the box  
✅ **Image optimization** - Downsampling to reduce memory usage  
✅ **Prefetching** - Load images before they're needed  
✅ **Error handling** - Retry logic and fallback states  
✅ **Memory management** - Automatic cleanup on memory warnings  
✅ **Reusable components** - Ready-to-use SwiftUI views  
✅ **Cache management** - Settings UI to manage cache  
✅ **Testable** - Mock implementations for testing  

---

**Next Steps:**

1. ✅ Add Kingfisher package dependency
2. ✅ Create `ImageCacheService.swift` in `Core/Services/`
3. ✅ Update `DIContainer.swift` to include the service
4. ✅ Create reusable components in `Shared/Components/`
5. ✅ Use `CachedAsyncImage` or `AvatarView` in your views
6. ✅ (Optional) Add cache settings view

---

**Last Updated:** March 24, 2026  
**Project:** AppStarter
