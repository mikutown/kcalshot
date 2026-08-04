# Photo Source-Aware Saving Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent photos selected from the system photo library from being saved back as duplicates while retaining opt-in saving for camera captures.

**Architecture:** Represent a picked photo as one value containing its `UIImage` and a typed `PhotoSource`. Keep the save decision as a pure method on `PhotoSource`, then carry the complete selection through the picker, entry views, and capture view so the side-effect boundary can make the correct decision.

**Tech Stack:** Swift 5, SwiftUI, PhotosUI, Photos, XCTest, Xcode 16 project with iOS 17 deployment target

## Global Constraints

- Save an original image only when its source is the camera and “保存原图到相册” is enabled.
- Never save a photo-library selection back to the photo library.
- Preserve the existing save timing: direct save or transition to portion confirmation.
- Do not change meal thumbnail persistence, recognition behavior, settings UI, authorization UI, or localization copy.
- Preserve all unrelated uncommitted workspace changes; do not stage or commit files containing pre-existing user edits.

---

### Task 1: Model Photo Source and Save Policy

**Files:**
- Create: `kcalshot/Features/Capture/PhotoSelection.swift`
- Create: `kcalshotTests/PhotoSourceTests.swift`

**Interfaces:**
- Produces: `enum PhotoSource { case camera, library; func shouldSaveOriginal(isEnabled: Bool) -> Bool }`
- Produces: `struct PhotoSelection { let image: UIImage; let source: PhotoSource }`

- [ ] **Step 1: Write the failing save-policy tests**

```swift
import XCTest
@testable import kcalshot

final class PhotoSourceTests: XCTestCase {
    func testCameraPhotoIsSavedWhenSettingIsEnabled() {
        XCTAssertTrue(PhotoSource.camera.shouldSaveOriginal(isEnabled: true))
    }

    func testCameraPhotoIsNotSavedWhenSettingIsDisabled() {
        XCTAssertFalse(PhotoSource.camera.shouldSaveOriginal(isEnabled: false))
    }

    func testLibraryPhotoIsNotSavedWhenSettingIsEnabled() {
        XCTAssertFalse(PhotoSource.library.shouldSaveOriginal(isEnabled: true))
    }

    func testLibraryPhotoIsNotSavedWhenSettingIsDisabled() {
        XCTAssertFalse(PhotoSource.library.shouldSaveOriginal(isEnabled: false))
    }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -project kcalshot.xcodeproj -scheme kcalshot \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:kcalshotTests/PhotoSourceTests
```

Expected: build failure because `PhotoSource` does not exist. If that simulator is unavailable, select an installed iOS simulator from `xcrun simctl list devices available` and rerun the same test target.

- [ ] **Step 3: Add the minimal source model and policy**

```swift
import UIKit

enum PhotoSource {
    case camera
    case library

    func shouldSaveOriginal(isEnabled: Bool) -> Bool {
        guard isEnabled else { return false }
        switch self {
        case .camera: true
        case .library: false
        }
    }
}

struct PhotoSelection {
    let image: UIImage
    let source: PhotoSource
}
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the command from Step 2. Expected: all four `PhotoSourceTests` pass with no test failures.

- [ ] **Step 5: Review the diff without committing user-owned edits**

Run:

```bash
git diff --check
git diff -- kcalshot/Features/Capture/PhotoSelection.swift kcalshotTests/PhotoSourceTests.swift
```

Expected: no whitespace errors; the diff contains only the model and four policy tests. Do not commit yet because the next task completes the behavior and an overlapping user-modified file must remain unstaged.

### Task 2: Carry Photo Source Through the Capture Flow

**Files:**
- Modify: `kcalshot/Features/Capture/PhotoSourcePicker.swift`
- Modify: `kcalshot/Features/Capture/CaptureView.swift`
- Modify: `kcalshot/Features/Today/TodayView.swift`
- Modify: `kcalshot/Features/Diary/DayDetailView.swift`
- Test: `kcalshotTests/PhotoSourceTests.swift`

**Interfaces:**
- Consumes: `PhotoSelection(image: UIImage, source: PhotoSource)`
- Consumes: `PhotoSource.shouldSaveOriginal(isEnabled:) -> Bool`
- Changes: `photoSourcePicker(isPresented:onImagePicked:)` callback from `(UIImage) -> Void` to `(PhotoSelection) -> Void`
- Changes: `CaptureView.init(mode:selectedPhoto:targetDate:)` to accept `PhotoSelection?`

- [ ] **Step 1: Change the picker callback to return a complete selection**

Update `PhotoSourcePicker` so its callback type is `(PhotoSelection) -> Void`. Wrap camera results as:

```swift
onImagePicked(PhotoSelection(image: image, source: .camera))
```

Wrap photo-library results as:

```swift
onImagePicked(PhotoSelection(image: image, source: .library))
```

Keep the existing dismissal delay for camera capture and the existing async `PhotosPickerItem` loading behavior.

- [ ] **Step 2: Preserve the selection in both entry views**

In `TodayView` and `DayDetailView`, replace `@State private var pickedImage: UIImage?` with:

```swift
@State private var selectedPhoto: PhotoSelection?
```

Assign the picker result directly, clear it when the capture sheet closes, and construct the photo capture screen with:

```swift
CaptureView(mode: captureMode, selectedPhoto: selectedPhoto, targetDate: ...)
```

For `TodayView`, omit `targetDate` as before. Preserve text-mode presentation by allowing `selectedPhoto` to remain `nil`.

- [ ] **Step 3: Make CaptureView own the complete current selection**

Change the initializer and state to:

```swift
init(
    mode: InputMode = .photo,
    selectedPhoto: PhotoSelection? = nil,
    targetDate: Date = .now
) {
    self.mode = mode
    self.targetDate = targetDate
    _selectedPhoto = State(initialValue: selectedPhoto)
}

@State private var selectedPhoto: PhotoSelection?

private var image: UIImage? { selectedPhoto?.image }
```

In the capture view’s `photoSourcePicker` callback, assign the complete selection before clearing correction text and recognition state:

```swift
selectedPhoto = picked
correction = ""
vm.state = .idle
```

This makes replacement photos update their source together with the image.

- [ ] **Step 4: Guard the Photos side effect with source and setting**

Replace the existing save guard with:

```swift
private func saveOriginalPhotoToAlbum() {
    guard let selectedPhoto,
          selectedPhoto.source.shouldSaveOriginal(isEnabled: settings.saveOriginalPhoto) else {
        return
    }
    try? PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: selectedPhoto.image)
    }
}
```

Leave both existing calls from `directSave(_:)` and `confirmSave(_:)` in place so the timing does not change.

- [ ] **Step 5: Compile and run the focused tests**

Run:

```bash
xcodebuild test -project kcalshot.xcodeproj -scheme kcalshot \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:kcalshotTests/PhotoSourceTests
```

Expected: the app and test targets compile and all four focused tests pass. Resolve only source-propagation compiler errors; do not refactor unrelated SwiftUI code.

- [ ] **Step 6: Run the full test suite**

Run:

```bash
xcodebuild test -project kcalshot.xcodeproj -scheme kcalshot \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Expected: all `kcalshotTests` pass. If the sandbox cannot access CoreSimulator or DerivedData, rerun with the required environment approval and report any infrastructure limitation separately from code failures.

- [ ] **Step 7: Verify scope and workspace preservation**

Run:

```bash
git diff --check
git status --short
git diff -- kcalshot/Features/Capture/PhotoSelection.swift \
  kcalshot/Features/Capture/PhotoSourcePicker.swift \
  kcalshot/Features/Capture/CaptureView.swift \
  kcalshot/Features/Today/TodayView.swift \
  kcalshot/Features/Diary/DayDetailView.swift \
  kcalshotTests/PhotoSourceTests.swift
```

Expected: no whitespace errors; source changes are limited to typed photo-source propagation and the save guard. Do not stage or commit implementation files because `CaptureView.swift` already contains the user’s uncommitted Photos-saving work and staging it would mix ownership.

### Task 3: Manual Acceptance Check

**Files:**
- No code changes

**Interfaces:**
- Consumes: the completed photo-selection flow from Task 2
- Produces: acceptance evidence for the four user-visible combinations

- [ ] **Step 1: Verify camera behavior on a physical device**

With “保存原图到相册” enabled, take a new photo, recognize it, and confirm the result. Expected: exactly one new asset appears in Photos. Disable the setting and repeat. Expected: no new asset appears.

- [ ] **Step 2: Verify photo-library behavior on a physical device**

With the setting enabled, select an existing photo, recognize it, and confirm the result. Expected: the Photos asset count does not increase. Repeat with the setting disabled. Expected: the Photos asset count still does not increase.

- [ ] **Step 3: Verify replacement-photo source tracking**

Enter the recognition page with a library photo, tap the preview, replace it with a camera photo, and confirm while saving is enabled. Expected: the camera photo is saved. Repeat in reverse (camera photo replaced by library photo). Expected: no duplicate library asset is created.
