import Foundation
import MimeType
import NIOHTTP1

public protocol ResponseWriter {
    var header: HTTPHeaders { get }
    func write(_ s: String) -> Int
    func write(_ stream: BodyStream) -> Int
    func writeHeader(statusCode: HTTPResponseStatus)
    func setContentType(_ mimeType: MediaType)
}
