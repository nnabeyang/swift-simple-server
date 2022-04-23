import NIOCore
import NIOHTTP1

final class HTTPServerRequestDecoder: ChannelDuplexHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request
    typealias OutboundIn = Never

    enum RequestState {
        case ready
        case awaitingBody(Request)
        case awaitingEnd(Request, ByteBuffer)
        case skipping
    }

    var requestState: RequestState

    init() {
        self.requestState = .ready
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        assert(context.channel.eventLoop.inEventLoop)
        let part = self.unwrapInboundIn(data)
        switch part {
        case .head(let head):
            switch self.requestState {
            case .ready:
                let request: Request = .init(header: head, to: context.eventLoop)
                self.requestState = .awaitingBody(request)
            default: assertionFailure("Unexpected state: \(self.requestState)")
            }
        case .body(let buffer):
            switch self.requestState {
            case .ready, .awaitingEnd:
                assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let request):
                self.requestState = .awaitingEnd(request, buffer)
            case .skipping: break
            }
        case .end:
            switch self.requestState {
            case .ready: assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let request):
                context.fireChannelRead(self.wrapInboundOut(request))
            case .awaitingEnd(let request, _):
                context.fireChannelRead(self.wrapInboundOut(request))
            case .skipping: break
            }
            self.requestState = .ready
        }
    }

    func read(context: ChannelHandlerContext) {
        context.read()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.fireErrorCaught(error)
    }

    func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }
}
