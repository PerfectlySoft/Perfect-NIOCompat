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
	var method: HTTPMethod = .get
	var path: String = ""
	var pathComponents: [String] = []
	var queryParams: [(String, String)] = []
	var protocolVersion: (Int, Int) = (1, 1)
	var remoteAddress: (host: String, port: UInt16) = ("", 0)
	var serverAddress: (host: String, port: UInt16) = ("", 0)
	var serverName: String = ""
	var documentRoot: String = ""
	var urlVariables: [String : String] = [:]
	var scratchPad: [String : Any] = [:]
	private var headerStore = Dictionary<HTTPRequestHeader.Name, [UInt8]>()
	var headers: AnyIterator<(HTTPRequestHeader.Name, String)> {
		var g = headerStore.makeIterator()
		return AnyIterator<(HTTPRequestHeader.Name, String)> {
			guard let n = g.next() else {
				return nil
			}
			return (n.key, UTF8Encoding.encode(bytes: n.value))
		}
	}
	var postParams: [(String, String)] = []
	var postBodyBytes: [UInt8]? = nil
	var postBodyString: String? = nil
	var postFileUploads: [MimeReader.BodySpec]? = nil
	func header(_ named: HTTPRequestHeader.Name) -> String? {
		return nil
	}
	func addHeader(_ named: HTTPRequestHeader.Name, value: String) {
		
	}
	func setHeader(_ named: HTTPRequestHeader.Name, value: String) {
		
	}
}

class HTTP11Response: HTTPResponse {
	let request: HTTPRequest
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
	init(request: HTTPRequest) {
		self.request = request
	}
	func header(_ named: HTTPResponseHeader.Name) -> String? {
		return nil
	}
	func addHeader(_ named: HTTPResponseHeader.Name, value: String) -> Self {
		return self
	}
	func setHeader(_ named: HTTPResponseHeader.Name, value: String) -> Self {
		return self
	}
	func push(callback: @escaping (Bool) -> ()) {
		
	}
	func next() {
		
	}
	func completed() {
		
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

	private var boundRoutes: BoundRoutes?
	private var listeningRoutes: ListeningRoutes?
	
	/// Initialize the server object.
	public init() {}
	
	/// Add the Routes to this server.
	public func addRoutes(_ routes: Routes) {
		self.routes.add(routes)
	}
	
	/// Bind the server to the designated address/port
	public func bind() throws {
		
	}
	
	/// Start the server. Does not return until the server terminates.
	public func start() throws {
		
	}
	
	/// Stop the server by closing the accepting TCP socket. Calling this will cause the server to break out of the otherwise blocking `start` function.
	public func stop() {
		
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
