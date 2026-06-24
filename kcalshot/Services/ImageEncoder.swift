import UIKit

/// 把图片降采样并压缩为 JPEG，用于上传识别（降低 token 成本与流量）。
enum ImageEncoder {
    /// 长边上限（像素）。
    static let maxDimension: CGFloat = 1024
    static let jpegQuality: CGFloat = 0.7

    /// 返回压缩后的 JPEG Data。
    static func jpegData(from image: UIImage) -> Data? {
        downscaled(image).jpegData(compressionQuality: jpegQuality)
    }

    /// 返回 data URI（base64），用于 OpenAI 兼容的 image_url。
    static func base64DataURI(from image: UIImage) -> String? {
        guard let data = jpegData(from: image) else { return nil }
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }

    /// 用于本地缩略图保存的小图 JPEG。
    static func thumbnailData(from image: UIImage, maxDimension: CGFloat = 320) -> Data? {
        downscaled(image, maxDimension: maxDimension).jpegData(compressionQuality: 0.6)
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat = maxDimension) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
