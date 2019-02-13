//
//	HTTPServer.swift
//	PerfectLib
//
//	Created by Kyle Jessup on 2015-10-23.
//	Copyright (C) 2015 PerfectlySoft, Inc.
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

import Foundation
import PerfectHTTPC
import PerfectNIO
import PerfectLib

import protocol PerfectHTTPC.HTTPResponse
import protocol PerfectHTTPC.HTTPRequest
import enum PerfectHTTPC.HTTPMethod
import enum PerfectHTTPC.HTTPResponseStatus
import struct PerfectHTTPC.Routes

class HTTP11Request: HTTPRequest {
	let master: PerfectNIO.HTTPRequest
	
	var method: HTTPMethod {
		return master.method.compat
	}
	let path: String
	var pathComponents: [String] { return path.split(separator: "/").map(String.init) }
	var queryParams: [(String, String)] {
		guard let qd = master.searchArgs else {
			return []
		}
		return qd.map { $0 }
	}
	var protocolVersion: (Int, Int) = (1, 1)
	
	private func addrTup(_ addr: SocketAddress) -> (String, UInt16) {
		switch addr {
		case .v4(let v4):
			return (v4.host, addr.port ?? 0)
		case .v6(let v6):
			return (v6.host, addr.port ?? 0)
		case .unixDomainSocket(let u):
			return ("\(u)", 0)
		}
	}
	var remoteAddress: (host: String, port: UInt16) {
		guard let addr = master.remoteAddress else {
			return ("", 0)
		}
		return addrTup(addr)
	}
	var serverAddress: (host: String, port: UInt16) {
		guard let addr = master.localAddress else {
			return ("", 0)
		}
		return addrTup(addr)
	}
	var serverName: String = ""
	var documentRoot: String = ""
	var urlVariables: [String : String] = [:]
	var scratchPad: [String : Any] = [:]
	
	var headers: AnyIterator<(HTTPRequestHeader.Name, String)> {
		var g = master.headers.makeIterator()
		return AnyIterator<(HTTPRequestHeader.Name, String)> {
			guard let n = g.next() else {
				return nil
			}
			return (HTTPRequestHeader.Name.fromStandard(name: n.name),
					n.value)
		}
	}
	
	private var workingBuffer: [UInt8] = []
	var mimes: MimeReader?
	var postQueryDecoder: QueryDecoder?
	
	lazy var postParams: [(String, String)] = {
		if let mime = mimes {
			return mime.bodySpecs.filter { $0.file == nil }.map { ($0.fieldName, $0.fieldValue) }
		} else if let qd = postQueryDecoder {
			return qd.map { $0 }
		}
		return [(String, String)]()
	}()
	var postBodyBytes: [UInt8]? {
		get {
			if let _ = mimes {
				return nil
			}
			return workingBuffer
		}
		set {
			if let nv = newValue {
				workingBuffer = nv
			} else {
				workingBuffer.removeAll()
			}
		}
	}
	var postBodyString: String? {
		guard let bytes = postBodyBytes else {
			return nil
		}
		if bytes.isEmpty {
			return ""
		}
		return UTF8Encoding.encode(bytes: bytes)
	}
	var postFileUploads: [MimeReader.BodySpec]? {
		guard let mimes = self.mimes else {
			return nil
		}
		return mimes.bodySpecs
	}
	
	init(master: PerfectNIO.HTTPRequest, path: String) {
		self.master = master
		print("HTTP11Request path \(path)")
		self.path = path.hasPrefix("/") ? path : ("/" + path)
	}
	func header(_ named: HTTPRequestHeader.Name) -> String? {
		return master.headers[named.standardName].first
	}
}

class HTTP11Response: HTTPOutput, HTTPResponse {
	let request: HTTPRequest
	
	var headPromise: EventLoopPromise<HTTPOutput>?
	var bodyPromise: EventLoopPromise<IOData?>?
	var bodyAllocator: ByteBufferAllocator?
	var pushCallback: ((Bool) -> ())?
	var hasCompleted = false
	
	var status: HTTPResponseStatus = .ok
	var isStreaming: Bool = false
	var bodyBytes: [UInt8] = []
	var headerStore = Array<(HTTPResponseHeader.Name, String)>()
	var headers: AnyIterator<(HTTPResponseHeader.Name, String)> {
		var g = headerStore.makeIterator()
		return AnyIterator<(HTTPResponseHeader.Name, String)> {
			g.next()
		}
	}
	var handlers: IndexingIterator<[RequestHandler]>?
	init(request: HTTPRequest, promise: EventLoopPromise<HTTPOutput>) {
		self.request = request
		self.headPromise = promise
	}
	
	override func head(request: HTTPRequestInfo) -> HTTPHead? {
		let headers = HTTPHeaders(headerStore.map { ($0.0.standardName, $0.1) })
		let nstatus = NIOHTTP1.HTTPResponseStatus(statusCode: status.code)
		return HTTPHead(status: nstatus, headers: headers)
	}
	override func body(promise: EventLoopPromise<IOData?>, allocator: ByteBufferAllocator) {
		if let pcb = pushCallback {
			pushCallback = nil
			// push/completed has been called
			if !bodyBytes.isEmpty {
				var b = allocator.buffer(capacity: bodyBytes.count)
				b.write(bytes: bodyBytes)
				bodyBytes.removeAll()
				promise.futureResult.whenSuccess { _ in pcb(true) }
				promise.futureResult.whenFailure { _ in pcb(false) }
				promise.succeed(result: .byteBuffer(b))
			} else if hasCompleted {
				promise.succeed(result: nil)
			} else {
				// no data but push was called
				// wait for another push/completed
				bodyPromise = promise
				bodyAllocator = allocator
				pcb(true)
			}
		} else if hasCompleted {
			promise.succeed(result: nil)
		} else {
			// wait for push/completed
			bodyPromise = promise
			bodyAllocator = allocator
		}
	}
	func push(callback: @escaping (Bool) -> ()) {
		pushCallback = callback
		if let hp = headPromise {
			// head has not been sent yet
			headPromise = nil
			// body will be called to finish up
			hp.succeed(result: self)
		} else if let bp = bodyPromise, let a = bodyAllocator {
			// head has been sent
			// body was requested
			bodyPromise = nil
			bodyAllocator = nil
			body(promise: bp, allocator: a)
		} else {
			// we wait for body to be called
		}
	}
	
	func header(_ named: HTTPResponseHeader.Name) -> String? {
		for (n, v) in headerStore where n == named {
			return v
		}
		return nil
	}
	@discardableResult
	func addHeader(_ name: HTTPResponseHeader.Name, value: String) -> Self {
		headerStore.append((name, value))
		if case .contentLength = name {
//			contentLengthSet = true
		}
		return self
	}
	@discardableResult
	func setHeader(_ name: HTTPResponseHeader.Name, value: String) -> Self {
		var fi = [Int]()
		for i in 0..<headerStore.count {
			let (n, _) = headerStore[i]
			if n == name {
				fi.append(i)
			}
		}
		fi = fi.reversed()
		for i in fi {
			headerStore.remove(at: i)
		}
		return addHeader(name, value: value)
	}
	func next() {
		if let n = handlers?.next() {
			n(request, self)
		} else {
			completed()
		}
	}
	func completed() {
		hasCompleted = true
		push {
			_ in
			
		}
	}
}

/// Stand-alone HTTP server.
public class HTTPServer: ServerInstance {
	public typealias certKeyPair = (sslCert: String, sslKey: String)
	/// The directory in which web documents are sought.
	/// Setting the document root will add a default URL route which permits
	/// static files to be served from within.
	public var documentRoot = "./webroot" { // Given a "safe" default
		didSet {
			self.routes.add(method: .get, uri: "/**", handler: {
				request, response in
				StaticFileHandler(documentRoot: request.documentRoot).handleRequest(request: request, response: response)
			})
		}
	}
	/// The port on which the server is listening.
	public var serverPort: UInt16 = 0
	/// The local address on which the server is listening. The default of 0.0.0.0 indicates any address.
	public var serverAddress = "0.0.0.0"
	/// Switch to user after binding port
	public var runAsUser: String?
	/// The canonical server name.
	/// This is important if utilizing the `HTTPRequest.serverName` property.
	public var serverName = ""
	public var ssl: certKeyPair?
	public var caCert: String?
	public var certVerifyMode: OpenSSLVerifyMode?
	public var cipherList = [
		"ECDHE-ECDSA-AES256-GCM-SHA384",
		"ECDHE-ECDSA-AES128-GCM-SHA256",
		"ECDHE-ECDSA-AES256-CBC-SHA384",
		"ECDHE-ECDSA-AES256-CBC-SHA",
		"ECDHE-ECDSA-AES128-CBC-SHA256",
		"ECDHE-ECDSA-AES128-CBC-SHA",
		"ECDHE-RSA-AES256-GCM-SHA384",
		"ECDHE-RSA-AES128-GCM-SHA256",
		"ECDHE-RSA-AES256-CBC-SHA384",
		"ECDHE-RSA-AES128-CBC-SHA256",
		"ECDHE-RSA-AES128-CBC-SHA",
		"ECDHE-RSA-AES256-SHA384",
		"ECDHE-ECDSA-AES256-SHA384",
		"ECDHE-RSA-AES256-SHA",
		"ECDHE-ECDSA-AES256-SHA"]
	
	var requestFilters = [[HTTPRequestFilter]]()
	var responseFilters = [[HTTPResponseFilter]]()
	
	/// Routing support
	private var routes = Routes()
	private var routeNavigator: RouteNavigator?
	
	public enum ALPNSupport: String {
		case http11 = "http/1.1", http2 = "h2"
	}
	public var alpnSupport = [ALPNSupport.http11]

	var boundRoutes: BoundRoutes?
	var listeningRoutes: ListeningRoutes?
	
	/// Initialize the server object.
	public init() {}
	
	/// Add the Routes to this server.
	public func addRoutes(_ routes: Routes) {
		self.routes.add(routes)
	}
	
	private func runRequest(_ request: HTTP11Request, promise: EventLoopPromise<HTTPOutput>) {
		let response = HTTP11Response(request: request, promise: promise)
		if let nav = routeNavigator,
			let handlers = nav.findHandlers(pathComponents: request.pathComponents, webRequest: request) {
			response.handlers = handlers.makeIterator()
			response.next()
		} else {
			response.status = .notFound
			response.appendBody(string: "The file \(request.path) was not found.")
			response.completed()
		}
	}
	
	private func handleBody(_ request: HTTP11Request, _ body: HTTPRequestContentType) -> HTTP11Request {
		switch body {
		case .none:
			()
		case .multiPartForm(let m):
			request.mimes = m
		case .urlForm(let q):
			request.postQueryDecoder = q
		case .other(let b):
			request.postBodyBytes = b
		}
		return request
	}
	
	/// Bind the server to the designated address/port
	public func bind() throws {
		routeNavigator = routes.navigator
		boundRoutes = try root()
			.trailing(HTTP11Request.init)
			.readBody(handleBody)
			.async(runRequest)
			.bind(port: Int(serverPort),
				  address: serverAddress, tls: nil)
	}
	
	/// Start the server. Does not return until the server terminates.
	public func start() throws {
		listeningRoutes = try boundRoutes?.listen()
		try listeningRoutes?.wait()
	}
	
	/// Stop the server by closing the accepting TCP socket. Calling this will cause the server to break out of the otherwise blocking `start` function.
	public func stop() {
		listeningRoutes?.stop()
	}
	
	/// Set the request filters. Each is provided along with its priority.
	/// The filters can be provided in any order. High priority filters will be sorted above lower priorities.
	/// Filters of equal priority will maintain the order given here.
	@discardableResult
	public func setRequestFilters(_ request: [(HTTPRequestFilter, HTTPFilterPriority)]) -> HTTPServer {
		let high = request.filter { $0.1 == HTTPFilterPriority.high }.map { $0.0 },
			med = request.filter { $0.1 == HTTPFilterPriority.medium }.map { $0.0 },
		    low = request.filter { $0.1 == HTTPFilterPriority.low }.map { $0.0 }
		if !high.isEmpty {
			requestFilters.append(high)
		}
		if !med.isEmpty {
			requestFilters.append(med)
		}
		if !low.isEmpty {
			requestFilters.append(low)
		}
		return self
	}
	
	/// Set the response filters. Each is provided along with its priority.
	/// The filters can be provided in any order. High priority filters will be sorted above lower priorities.
	/// Filters of equal priority will maintain the order given here.
	@discardableResult
	public func setResponseFilters(_ response: [(HTTPResponseFilter, HTTPFilterPriority)]) -> HTTPServer {
		let high = response.filter { $0.1 == HTTPFilterPriority.high }.map { $0.0 },
		    med = response.filter { $0.1 == HTTPFilterPriority.medium }.map { $0.0 },
		    low = response.filter { $0.1 == HTTPFilterPriority.low }.map { $0.0 }
		if !high.isEmpty {
			responseFilters.append(high)
		}
		if !med.isEmpty {
			responseFilters.append(med)
		}
		if !low.isEmpty {
			responseFilters.append(low)
		}
		return self
	}
}

extension PerfectNIO.HTTPMethod {
	var compat: PerfectHTTPC.HTTPMethod {
		switch self {
		case .GET:
			return .get
		case .PUT:
			return .put
		case .HEAD:
			return .head
		case .POST:
			return .post
		case .PATCH:
			return .patch
		case .TRACE:
			return .trace
		case .DELETE:
			return .delete
		case .CONNECT:
			return .connect
		case .OPTIONS:
			return .options
		case .ACL:
			return .custom("ACL")
		case .COPY:
			return .custom("COPY")
		case .LOCK:
			return .custom("LOCK")
		case .MOVE:
			return .custom("MOVE")
		case .BIND:
			return .custom("BIND")
		case .LINK:
			return .custom("LINK")
		case .MKCOL:
			return .custom("MKCOL")
		case .MERGE:
			return .custom("MERGE")
		case .PURGE:
			return .custom("PURGE")
		case .NOTIFY:
			return .custom("NOTIFY")
		case .SEARCH:
			return .custom("SEARCH")
		case .UNLOCK:
			return .custom("UNLOCK")
		case .REBIND:
			return .custom("REBIND")
		case .UNBIND:
			return .custom("UNBIND")
		case .REPORT:
			return .custom("REPORT")
		case .UNLINK:
			return .custom("UNLINK")
		case .MSEARCH:
			return .custom("MSEARCH")
		case .PROPFIND:
			return .custom("PROPFIND")
		case .CHECKOUT:
			return .custom("CHECKOUT")
		case .PROPPATCH:
			return .custom("PROPPATCH")
		case .SUBSCRIBE:
			return .custom("SUBSCRIBE")
		case .MKCALENDAR:
			return .custom("MKCALENDAR")
		case .MKACTIVITY:
			return .custom("MKACTIVITY")
		case .UNSUBSCRIBE:
			return .custom("UNSUBSCRIBE")
		case .RAW(let value):
			return .custom(value)
		}
	}
}
