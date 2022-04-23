import NIOCore
import NIOHTTP1

extension ChannelPipeline {
    func addHTTPServerPipeline(responder: Responder) -> EventLoopFuture<Void> {
        self.eventLoop.assertInEventLoop()
        return addHandlers(
            [
                HTTPResponseEncoder(),
                ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)),
                HTTPServerResponseEncoder(),
                HTTPServerRequestDecoder(),
                HTTPServerHandler(responder: responder),
            ],
            position: .last)
    }
}
