import Foundation

/// Configuration for image loading network requests.
public enum ImageLoaderConfig {
    
    /// Shared URLSession with custom configuration for image loading.
    public static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "ImageLoaderCache"
        )
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
    
    /// Builds a URLRequest for an image URL with proper headers and caching.
    /// - Parameter url: The image URL to request.
    /// - Returns: Configured URLRequest.
    public static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30
        request.setValue("Meowbah/1.0 (iOS; SwiftUI)", forHTTPHeaderField: "User-Agent")
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        return request
    }
}
