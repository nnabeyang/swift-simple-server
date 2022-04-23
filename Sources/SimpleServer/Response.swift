import Foundation
import NIOCore
import NIOHTTP1

public protocol Response {
    var method: HTTPMethod { get set }
    var url: URL { get set }
    var version: HTTPVersion { get }
    var status: HTTPResponseStatus { get set }
    var header: HTTPHeaders { get set }
    var body: Body { get set }
}

public enum BodyStreamResult {
    case buffer(ByteBuffer)
    case string(String)
    case error(Error)
    case end(BodyStream?)
}

public protocol BodyStreamWriter {
    var eventLoop: EventLoop { get }
    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?)
}

extension BodyStreamWriter {
    public func write(_ result: BodyStreamResult) -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        self.write(result, promise: promise)
        return promise.futureResult
    }
}

public class BodyStream {
    let count: Int
    let callback: (BodyStreamWriter, BodyStream?) -> Void
    var next: BodyStream?
    var prev: BodyStream?
    init(count: Int, callback: @escaping (BodyStreamWriter, BodyStream?) -> Void) {
        self.count = count
        self.callback = callback
    }
}

public struct Body {
    internal enum Storage {
        case none
        case pipeline(BodyStream, BodyStream)
    }

    public static let empty: Body = .init()

    public var count: Int {
        switch self.storage {
        case .none: return 0
        case .pipeline(let head, _):
            var c = 0
            var p: BodyStream? = head
            while p?.next != nil {
                c += p?.count ?? 0
                p = p?.next
            }
            return c
        }
    }

    public var data: Data? {
        switch self.storage {
        case .none: return nil
        case .pipeline: return nil
        }
    }

    internal var storage: Storage

    public init() {
        self.storage = .none
    }

    public init(
        pipeline: (BodyStream, BodyStream), stream current: BodyStream
    ) {
        let (head, tail) = pipeline
        current.next = tail
        if let prev = tail.prev {
            current.prev = prev
            prev.next = current
        }
        tail.prev = current
        self.storage = .pipeline(head, tail)
    }

    public init(
        pipeline: (BodyStream, BodyStream), stream: @escaping (BodyStreamWriter, BodyStream?) -> Void, count: Int
    ) {
        self.init(pipeline: pipeline, stream: .init(count: count, callback: stream))
    }
}
