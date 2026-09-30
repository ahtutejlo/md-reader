import UniformTypeIdentifiers
import WebKit

/// Serves local images to the preview, which has no file access of its own.
/// Only image files are served, so a markdown file cannot pull in anything else.
final class LocalAssetSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "md-asset"

    static func url(for fileURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "local"
        components.path = fileURL.path
        return components.url
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
              let data = try? Data(contentsOf: URL(fileURLWithPath: url.path), options: .mappedIfSafe) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        task.didReceive(URLResponse(url: url, mimeType: type.preferredMIMEType, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
