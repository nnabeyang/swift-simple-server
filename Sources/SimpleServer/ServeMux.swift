import NIOCore

public protocol Handler {
    func serveHTTP(_ rw: ResponseWriter, _ req: Request)
}

public final class HandlerFunc: Handler {
    typealias HandlerProc = (ResponseWriter, Request) -> Void
    let f: HandlerProc
    init(_ f: @escaping HandlerProc) {
        self.f = f
    }
    public func serveHTTP(_ rw: ResponseWriter, _ req: Request) {
        f(rw, req)
    }
}

func NotFoundHandler() -> Handler {
    return HandlerFunc { (w, r) in
        w.writeHeader(statusCode: .notFound)
        _ = w.write("404 page not found")
    }
}

public class ServeMux: Responder {
    struct MuxEntry {
        let pattern: String
        let h: Handler
    }
    public init() {}
    private var m: [String: MuxEntry] = [:]
    var es: [MuxEntry] = []

    public func handleFunc(pattern: String, handler: @escaping (ResponseWriter, Request) -> Void) {
        handle(pattern: pattern, handler: HandlerFunc(handler))
    }
    public func handle(pattern: String, handler: Handler) {
        let e = MuxEntry(pattern: pattern, h: handler)
        m[pattern] = e
        if pattern[pattern.index(pattern.endIndex, offsetBy: -1)] == "/" {
            appendSort(e)
        }
    }
    func appendSort(_ e: MuxEntry) {
        guard
            let i = es.firstIndex(where: {
                $0.pattern.count < e.pattern.count
            })
        else {
            es.append(e)
            return
        }
        es.insert(e, at: i)
    }

    public func respond(to request: Request) -> EventLoopFuture<Response> {
        let cw = ChunkWriter()
        let (h, _) = handler(request)
        h.serveHTTP(cw, request)
        return request.eventLoop.makeSucceededFuture(cw)
    }

    func handler(_ req: Request) -> (Handler, String) {
        switch match(req.header.uri) {
        case .success(let r):
            return r
        case .failure:
            return (NotFoundHandler(), "")
        }
    }

    private func match(_ path: String) -> Swift.Result<(Handler, String), RouteError> {
        if let v = m[path] {
            return .success((v.h, v.pattern))
        }
        for e in es {
            if path.hasPrefix(e.pattern) {
                return .success((e.h, e.pattern))
            }
        }
        return .failure(.notFound)
    }
}

enum RouteError: Error {
    case notFound
}
