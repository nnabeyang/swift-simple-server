import Foundation
import MimeType
import NIOHTTP1

class ChunkWriter {
    var method: HTTPMethod = .GET
    let version: HTTPVersion = .http1_0
    var body: Body = .init() {
        didSet {
            let count = body.count.description
            if count != header.first(name: "Content-Length") {
                header.replaceOrAdd(name: "Content-Length", value: count)
            }
        }
    }
    var status: HTTPResponseStatus = .ok
    var header: HTTPHeaders = .init()
    var url: URL = .init(fileURLWithPath: "")
    private var wroteHeader: Bool = false
}

extension ChunkWriter: ResponseWriter {
    func write(_ stream: BodyStream) -> Int {
        if !wroteHeader {
            writeHeader(statusCode: .ok)
        }

        switch body.storage {
        case .none:
            let head: BodyStream = .init(count: 0, callback: { _, _ in })
            let tail: BodyStream = .init(count: 0, callback: { stream, _ in _ = stream.write(.end(nil)) })
            head.next = tail
            tail.prev = head
            body = .init(pipeline: (head, tail), stream: stream)
        case .pipeline(let head, let tail):
            body = .init(pipeline: (head, tail), stream: stream)
        }
        return stream.count
    }

    func write(_ s: String) -> Int {
        if !wroteHeader {
            writeHeader(statusCode: .ok)
        }
        let n = s.utf8.count
        switch body.storage {
        case .none:
            let head: BodyStream = .init(count: 0, callback: { _, _ in })
            let tail: BodyStream = .init(count: 0, callback: { stream, _ in _ = stream.write(.end(nil)) })
            head.next = tail
            tail.prev = head
            body = .init(
                pipeline: (head, tail),
                stream: { stream, next in
                    stream.write(.string(s)).whenComplete { result in
                        switch result {
                        case .failure(let error):
                            stream.write(.error(error), promise: nil)
                        case .success:
                            stream.write(.end(next), promise: nil)
                        }
                    }
                }, count: n)
        case .pipeline(let head, let tail):
            body = .init(
                pipeline: (head, tail),
                stream: { stream, next in
                    stream.write(.string(s)).whenComplete { result in
                        switch result {
                        case .failure(let error):
                            stream.write(.error(error), promise: nil)
                        case .success:
                            stream.write(.end(next), promise: nil)
                        }
                    }
                }, count: n)
        }

        return n
    }

    func writeHeader(statusCode: HTTPResponseStatus) {
        wroteHeader = true
        status = statusCode
    }
}

extension ChunkWriter: Response {
    func setContentType(_ mimeType: MediaType) {
        self.header.replaceOrAdd(name: "Content-Type", value: mimeType.serialize())
    }
}
