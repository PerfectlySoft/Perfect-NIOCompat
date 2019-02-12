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

import PerfectHTTPC

/// This class represents the communications channel for a WebSocket session.
public class WebSocket: Equatable {

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
	
	/// Close the connection.
	public func close() {
	
	}

	/// Read string data from the client.
	public func readStringMessage(continuation: @escaping (String?, _ opcode: OpcodeType, _ final: Bool) -> ()) {
	
	}

	/// Read binary data from the client.
	public func readBytesMessage(continuation: @escaping ([UInt8]?, _ opcode: OpcodeType, _ final: Bool) -> ()) {
	
	}

	/// Send binary data to thew client.
	public func sendBinaryMessage(bytes: [UInt8], final: Bool, completion: @escaping () -> ()) {
	
	}

	/// Send string data to the client.
	public func sendStringMessage(string: String, final: Bool, completion: @escaping () -> ()) {
	
	}

	/// Send a "pong" message to the client.
	public func sendPong(completion: @escaping () -> ()) {
	
	}

	/// Send a "ping" message to the client.
	/// Expect a "pong" message to follow.
	public func sendPing(completion: @escaping () -> ()) {
	
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

	}
}
