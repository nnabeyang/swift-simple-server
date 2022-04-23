import NIOCore

final class HTTPServerHandler: ChannelInboundHandler {
    typealias InboundIn = Request
    typealias OutboundOut = Response

    let responder: Responder
    var isShuttingDown: Bool

    init(responder: Responder) {
        self.responder = responder
        self.isShuttingDown = false
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        self.responder.respond(to: request).whenComplete { response in
            self.serialize(response, for: request, context: context)
        }
    }

    func serialize(_ response: Result<Response, Error>, for request: Request, context: ChannelHandlerContext) {
        switch response {
        case .failure(let error):
            self.errorCaught(context: context, error: error)
        case .success(let response):
            self.serialize(response, for: request, context: context)
        }
    }

    func serialize(_ response: Response, for request: Request, context: ChannelHandlerContext) {
        let done = context.write(self.wrapOutboundOut(response))
        done.whenComplete { result in
            switch result {
            case .success:
                context.close(mode: .output, promise: nil)
            case .failure(let error):
                self.errorCaught(context: context, error: error)
            }
        }

    }
}
