//
//  WebSocketHandler.swift
//  PerfectLib
//
//  Created by Kyle Jessup on 2016-01-06.
//  Copyright © 2016 PerfectlySoft. All rights reserved.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectHTTPC
import PerfectHTTPServerC
import class PerfectNIO.WebSocketUpgradeHTTPOutput
import protocol PerfectNIO.WebSocket

typealias CompatWebSocket = PerfectNIO.WebSocket

/// This class represents the communications channel for a WebSocket session.
public class WebSocket: Equatable {
	
	let master: CompatWebSocket
	
	/// The various types of WebSocket messages.
	public enum OpcodeType: UInt8 {
        /// Continuation op code
		case continuation = 0x0,
        /// Text data indicator
        text = 0x1,
        /// Binary data indicator
        binary = 0x2,
        /// Close indicator
        close = 0x8,
        /// Ping message
        ping = 0x9,
        /// Ping response message
        pong = 0xA,
        /// Invalid op code
        invalid
	}

	/// The read timeout, in seconds. By default this is -1, which means no timeout.
	public var readTimeoutSeconds: Double = -1
	
    /// Indicates if the socket is still likely connected or if it has been closed.
	public var isConnected = false
	
	init(master: CompatWebSocket) {
		self.master = master
	}
	
	/// Close the connection.
	public func close() {
		_ = master.writeMessage(.close)
	}

	/// Read string data from the client.
	public func readStringMessage(continuation: @escaping (String?, _ opcode: OpcodeType, _ final: Bool) -> ()) {
		let p = master.readMessage()
		p.whenSuccess {
			msg in
			switch msg {
			case .close:
				self.isConnected = false
				continuation(nil, OpcodeType.close, true)
			case .ping, .pong:
				self.readStringMessage(continuation: continuation)
			case .text(let t):
				continuation(t, OpcodeType.text, true)
			case .binary(let b):
				continuation(UTF8Encoding.encode(bytes: b), OpcodeType.binary, true)
			}
		}
		p.whenFailure {
			_ in
			_ = self.master.writeMessage(.close)
			continuation(nil, OpcodeType.close, true)
		}
	}

	/// Read binary data from the client.
	public func readBytesMessage(continuation: @escaping ([UInt8]?, _ opcode: OpcodeType, _ final: Bool) -> ()) {
		let p = master.readMessage()
		p.whenSuccess {
			msg in
			switch msg {
			case .close:
				self.isConnected = false
				continuation(nil, OpcodeType.close, true)
			case .ping, .pong:
				self.readBytesMessage(continuation: continuation)
			case .text(let t):
				continuation(Array(t.utf8), OpcodeType.text, true)
			case .binary(let b):
				continuation(b, OpcodeType.binary, true)
			}
		}
		p.whenFailure {
			_ in
			_ = self.master.writeMessage(.close)
			continuation(nil, OpcodeType.close, true)
		}
	}

	/// Send binary data to thew client.
	public func sendBinaryMessage(bytes: [UInt8], final: Bool, completion: @escaping () -> ()) {
		master.writeMessage(.binary(bytes)).whenComplete(completion)
	}

	/// Send string data to the client.
	public func sendStringMessage(string: String, final: Bool, completion: @escaping () -> ()) {
		master.writeMessage(.text(string)).whenComplete(completion)
	}

	/// Send a "pong" message to the client.
	public func sendPong(completion: @escaping () -> ()) {
		master.writeMessage(.pong).whenComplete(completion)
	}

	/// Send a "ping" message to the client.
	/// Expect a "pong" message to follow.
	public func sendPing(completion: @escaping () -> ()) {
		master.writeMessage(.ping).whenComplete(completion)
	}

	/// implement Equatable protocol
	public static func == (lhs: WebSocket, rhs: WebSocket) -> Bool {
		return lhs === rhs
	}
}

/// The protocol that all WebSocket handlers must implement.
public protocol WebSocketSessionHandler {

	/// Optionally indicate the name of the protocol the handler implements.
	/// If this has a valid, the protocol name will be validated against what the client is requesting.
	var socketProtocol: String? { get }
	/// This function is called once the WebSocket session has been initiated.
	func handleSession(request req: HTTPRequest, socket: WebSocket)

}

/// This request handler accepts WebSocket requests from client.
/// It will initialize the session and then deliver it to the `WebSocketSessionHandler`.
public struct WebSocketHandler {

    /// Function which produces a WebSocketSessionHandler
	public typealias HandlerProducer = (_ request: HTTPRequest, _ protocols: [String]) -> WebSocketSessionHandler?

	private let handlerProducer: HandlerProducer

    /// Initialize WebSocketHandler with a handler producer function
	public init(handlerProducer: @escaping HandlerProducer) {
		self.handlerProducer = handlerProducer
	}

    /// Handle the request and negotiate the WebSocket session
	public func handleRequest(request: HTTPRequest, response: HTTPResponse) {
		guard let req11 = request as? HTTP11Request,
			let resp11 = response as? HTTP11Response else {
			return response.completed(status: .internalServerError)
		}
		let master = req11.master
		resp11.proxy = WebSocketUpgradeHTTPOutput(request: master) {
			socket in
			let subSocket = WebSocket(master: socket)
			let secWebSocketProtocol = request.header(.custom(name: "sec-websocket-protocol")) ?? ""
			let protocolList = secWebSocketProtocol.split(separator: ",").compactMap {
				i -> String? in
				var s = String(i)
				while s.count > 0 && s[s.startIndex] == " " {
					s.remove(at: s.startIndex)
				}
				return s.count > 0 ? s : nil
			}
			let handler = self.handlerProducer(request, protocolList)
			handler?.handleSession(request: request, socket: subSocket)
		}
		response.push {
			ok in
		}
	}
}
