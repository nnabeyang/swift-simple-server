import NIOCore
import NIOHTTP1

public class Request {
    public var header: HTTPRequestHead!
    public let eventLoop: EventLoop
    init(header: HTTPRequestHead, to eventLoop: EventLoop) {
        self.header = header
        self.eventLoop = eventLoop
    }
}
