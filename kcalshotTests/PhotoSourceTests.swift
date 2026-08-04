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
