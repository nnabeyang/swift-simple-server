import NIOCore
import NIOHTTP1

final class HTTPServerResponseEncoder: ChannelOutboundHandler {
    typealias OutboundIn = Response
    typealias OutboundOut = HTTPServerResponsePart

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = self.unwrapOutboundIn(data)
        context.write(
            wrapOutboundOut(
                .head(
                    .init(
                        version: response.version,
                        status: response.status,
                        headers: response.header
                    ))), promise: nil)

        switch response.body.storage {
        case .none:
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
        case .pipeline(let head, _):
            guard let stream = head.next else {
                return
            }
            let channelStream = ChannelResponseBodyStream(
                context: context,
                handler: self,
                promise: promise,
                count: stream.count == -1 ? nil : stream.count
            )
            stream.callback(channelStream, stream.next)
        }

    }

    private func writeAndflush(buffer: ByteBuffer, context: ChannelHandlerContext, promise: EventLoopPromise<Void>?) {
        if buffer.readableBytes > 0 {
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
    }
}

private final class ChannelResponseBodyStream: BodyStreamWriter {
    let context: ChannelHandlerContext
    let handler: HTTPServerResponseEncoder
    let promise: EventLoopPromise<Void>?
    let count: Int?
    var currentCount: Int
    var isComplete: Bool

    var eventLoop: EventLoop {
        return self.context.eventLoop
    }

    enum Error: Swift.Error {
        case tooManyBytes
        case notEnoughBytes
    }

    init(
        context: ChannelHandlerContext,
        handler: HTTPServerResponseEncoder,
        promise: EventLoopPromise<Void>?,
        count: Int?
    ) {
        self.context = context
        self.handler = handler
        self.promise = promise
        self.count = count
        self.currentCount = 0
        self.isComplete = false
    }

    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?) {
        switch result {
        case .buffer(let buffer):
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
            self.currentCount += buffer.readableBytes
        case .string(let string):
            var buffer = context.channel.allocator.buffer(capacity: string.count)
            buffer.writeString(string)
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
        case .end(let next):
            if let stream = next {
                stream.callback(self, stream.next)
            } else {
                self.isComplete = true
                if let count = self.count, self.currentCount != count {
                    self.promise?.fail(Error.notEnoughBytes)
                    promise?.fail(Error.notEnoughBytes)
                }
                self.context.writeAndFlush(self.handler.wrapOutboundOut(.end(nil)), promise: promise)
                self.promise?.succeed(())
            }
        case .error(let error):
            self.isComplete = true
            self.context.writeAndFlush(self.handler.wrapOutboundOut(.end(nil)), promise: promise)
            self.promise?.fail(error)
        }
    }

    deinit {
        assert(self.isComplete)
    }
}
