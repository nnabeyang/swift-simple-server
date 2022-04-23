import Foundation
import MimeType
import NIOCore
import NIOPosix

public class FileHandler: Handler {
    private let root: NBFileSystem

    public init(root: NBFileSystem) {
        self.root = root
    }

    public func serveHTTP(_ rw: ResponseWriter, _ req: Request) {
        let requestPath = req.header.uri
        switch root.open(forReadingAtPath: requestPath, eventLoop: req.eventLoop) {
        case .success(let f):
            if let ext = requestPath.split(separator: ".").last,
                let contentType = fileExtension(String(ext))
            {
                rw.setContentType(contentType)
            }
            _ = rw.write(
                .init(
                    count: f.fileSize,
                    callback: { stream, next in
                        f.read(fromOffset: 0) { chunk in
                            return stream.write(.buffer(chunk))
                        }.whenComplete { result in
                            switch result {
                            case .failure(let error):
                                stream.write(.error(error), promise: nil)
                            case .success:
                                stream.write(.end(next), promise: nil)
                            }
                        }
                    }))
        case .failure(let error):
            rw.writeHeader(statusCode: error.status)
            _ = rw.write(error.reason)
            break
        }
    }
}

public protocol NBFile {
    var fileSize: Int { get }
    func read(
        fromOffset offset: Int64,
        onRead: @escaping (ByteBuffer) -> EventLoopFuture<Void>
    ) -> EventLoopFuture<Void>
}

public protocol NBFileSystem {
    func open(forReadingAtPath path: String, eventLoop: EventLoop) -> Swift.Result<NBFile, Abort>
}

public class Dir: NBFileSystem {
    private let base: String
    private let io: NonBlockingFileIO
    private let allocator: ByteBufferAllocator

    public init(base: String, io: NonBlockingFileIO) {
        self.base = base
        self.io = io
        self.allocator = .init()
    }

    public func open(forReadingAtPath path: String, eventLoop: EventLoop) -> Result<NBFile, Abort> {
        var fpath = "\(base)\(path)"
        do {
            var isDir: ObjCBool = false
            guard
                FileManager.default.fileExists(
                    atPath: fpath,
                    isDirectory: &isDir
                )
            else {
                return .failure(Abort(.notFound))
            }

            if isDir.boolValue {
                fpath = fpath + "index.html"
                guard
                    FileManager.default.fileExists(
                        atPath: fpath,
                        isDirectory: &isDir
                    )
                else {
                    return .failure(Abort(.notFound))
                }
            }

            guard
                let attributes = try? FileManager.default.attributesOfItem(atPath: fpath),
                let fileSize = attributes[.size] as? NSNumber
            else {
                return .failure(Abort(.internalServerError))
            }

            let f = try NIOFile(
                path: fpath,
                io: io,
                allocator: allocator,
                chunkSize: NonBlockingFileIO.defaultChunkSize,
                fileSize: fileSize.intValue,
                to: eventLoop)
            return .success(f)
        } catch {
            return .failure(Abort(.internalServerError))
        }
    }
}

class NIOFile: NBFile {
    private let fd: NIOFileHandle
    private let io: NonBlockingFileIO
    private let allocator: ByteBufferAllocator
    private let chunkSize: Int
    let fileSize: Int
    private let eventLoop: EventLoop

    init(
        path: String,
        io: NonBlockingFileIO,
        allocator: ByteBufferAllocator,
        chunkSize: Int = NonBlockingFileIO.defaultChunkSize,
        fileSize: Int,
        to eventLoop: EventLoop
    ) throws {
        self.fd = try .init(path: path)
        self.io = io
        self.allocator = allocator
        self.chunkSize = chunkSize
        self.fileSize = fileSize
        self.eventLoop = eventLoop
    }

    func read(
        fromOffset offset: Int64,
        onRead: @escaping (ByteBuffer) -> EventLoopFuture<Void>
    ) -> EventLoopFuture<Void> {
        let fd = self.fd
        let done = io.readChunked(
            fileHandle: fd,
            byteCount: fileSize,
            allocator: allocator,
            eventLoop: eventLoop
        ) { chunk in
            return onRead(chunk)
        }
        done.whenComplete { _ in
            try? fd.close()
        }
        return done
    }
}
