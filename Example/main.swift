import Foundation
import MimeType
import NIOCore
import NIOPosix
import SimpleServer

loadMimeFile(atPath: "/etc/apache2/mime.types")

let threadPool = NIOThreadPool(numberOfThreads: 6)
threadPool.start()
defer {
    try! threadPool.syncShutdownGracefully()
}
let io = NonBlockingFileIO(threadPool: threadPool)
let mux = ServeMux()
let url = Bundle.module.url(forResource: "static", withExtension: nil)!
mux.handle(pattern: "/", handler: FileHandler(root: Dir(base: url.path, io: io)))
mux.handleFunc(pattern: "/hello/simple-server/") { (w, _) in
    _ = w.write("Hello SimpleServer")
}
listenAndServe(host: "localhost", port: 3000, responder: mux)
