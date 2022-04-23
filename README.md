# swift-simple-server

A simple HTTP server in pure Swift.

## Usage

```swift
import MimeType
import SimpleServer
import NIOCore
import NIOPosix

loadMimeFile(atPath: "/etc/apache2/mime.types")

let threadPool = NIOThreadPool(numberOfThreads: 6)
threadPool.start()
defer {
    try! threadPool.syncShutdownGracefully()
}
let io = NonBlockingFileIO(threadPool: threadPool)
let mux = ServeMux()
mux.handle(pattern: "/", handler: FileHandler(root: Dir(base: "./public", io: io)))
mux.handleFunc(pattern: "/hello/simple-server/") { (w, _) in
    _ = w.write("Hello SimpleServer")
}
listenAndServe(host: "localhost", port: 3000, responder: mux)
```

## Adding `SimpleServer` as a Dependency

To use the `SimpleServer` library in a SwiftPM project, 
add it to the dependencies for your package:

```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.33.0"),
        .package(url: "https://github.com/nnabeyang/swift-mime-type", from: "0.0.0"),
        .package(url: "https://github.com/nnabeyang/swift-simple-server", from: "0.0.0"),
    ],
    targets: [
        .executableTarget(name: "<executable-target-name>", dependencies: [
            // other dependencies
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "MimeType", package: "swift-mime-type"),
                .product(name: "SimpleServer", package: "swift-simple-server"),
        ]),
        // other targets
    ]
)
```

## License

swift-simple-server is published under the MIT License, see LICENSE.

## Author
[Noriaki Watanabe@nnabeyang](https://twitter.com/nnabeyang)
