import NIOHTTP1

public protocol AbortError: Error {
    var reason: String { get }
    var status: HTTPResponseStatus { get }
    var headers: HTTPHeaders { get }
}

public struct Abort: AbortError {
    public var status: HTTPResponseStatus
    public var headers: HTTPHeaders
    public var reason: String

    init(
        _ status: HTTPResponseStatus,
        headers: HTTPHeaders = [:],
        reason: String? = nil
    ) {
        self.headers = headers
        self.status = status
        self.reason = reason ?? status.reasonPhrase
    }
}
