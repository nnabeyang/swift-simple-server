import ConsoleKit
import Dispatch
import NIOCore
import NIOHTTP1
import NIOPosix

public func listenAndServe(host: String, port: Int, responder: Responder) {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let bootstrap = ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        .childChannelInitializer { channel in
            return channel.pipeline.addHTTPServerPipeline(responder: responder)
        }
    defer {
        try! group.syncShutdownGracefully()
    }
    do {
        let channel = try bootstrap.bind(host: host, port: port).wait()
        let localAddress: String

        guard let channelLocalAddress = channel.localAddress else {
            fatalError(
                "Address was unable to bind. Please check that the socket was not closed or that the address family was understood."
            )
        }
        localAddress = "\(channelLocalAddress)"

        print("Server started and listening on \(localAddress)")

        let promise = channel.eventLoop.next().makePromise(of: Void.self)
        let signalQueue = DispatchQueue(label: "codes.simple.server.shutdown")
        var signalSources: [DispatchSourceSignal] = []
        func makeSignalSource(_ code: Int32) {
            let source = DispatchSource.makeSignalSource(signal: code, queue: signalQueue)
            source.setEventHandler {
                print()  // clear ^C
                promise.succeed(())
            }
            source.resume()
            signalSources.append(source)
            signal(code, SIG_IGN)
        }
        makeSignalSource(SIGTERM)
        makeSignalSource(SIGINT)
        try promise.futureResult.wait()
    } catch {
        fatalError(error.localizedDescription)
    }
    print("Server closed")
}
