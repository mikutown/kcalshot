import UIKit

enum PhotoSource {
    case camera
    case library

    func shouldSaveOriginal(isEnabled: Bool) -> Bool {
        guard isEnabled else { return false }
        return switch self {
        case .camera: true
        case .library: false
        }
    }
}

struct PhotoSelection {
    let image: UIImage
    let source: PhotoSource
}
