//
//  HTTP11Response.swift
//  PerfectHTTPServerC
//
//  Created by Kyle Jessup on 2019-02-14.
//

import Foundation
import PerfectHTTPC
import PerfectNIO

import protocol PerfectHTTPC.HTTPRequest
import enum PerfectHTTPC.HTTPResponseStatus

public final class HTTP11Response: HTTPOutput, HTTPResponse {
	var requestP: HTTPRequest?
	public var request: HTTPRequest { return requestP! }
	public var proxy: HTTPOutput?
	
	var headPromise: EventLoopPromise<HTTPOutput>?
	var bodyPromise: EventLoopPromise<IOData?>?
	var bodyAllocator: ByteBufferAllocator?
	var pushCallback: ((Bool) -> ())?
	var hasCompleted = false
	
	public var status: HTTPResponseStatus = .ok
	public var isStreaming: Bool = false
	public var bodyBytes: [UInt8] = []
	var headerStore = Array<(HTTPResponseHeader.Name, String)>()
	public var headers: AnyIterator<(HTTPResponseHeader.Name, String)> {
		var g = headerStore.makeIterator()
		return AnyIterator<(HTTPResponseHeader.Name, String)> {
			g.next()
		}
	}
	var handlers: IndexingIterator<[RequestHandler]>?
	let responseFilters: [[HTTPResponseFilter]]
	
	init(request: HTTPRequest, responseFilters: [[HTTPResponseFilter]], promise: EventLoopPromise<HTTPOutput>) {
		self.requestP = request
		self.responseFilters = responseFilters
		self.headPromise = promise
	}
	deinit {
//		print("~HTTP11Response")
	}
	public override func closed() {
		super.closed()
		proxy = nil
		if let p = pushCallback {
			pushCallback = nil
			p(false)
		}
		(requestP as? HTTP11Request)?.masterP = nil
		requestP = nil
	}
	public override func head(request: HTTPRequestInfo) -> HTTPHead? {
		if let p = proxy {
			return p.head(request: request)
		}
		
		for filterSet in responseFilters {
			for filter in filterSet {
				var brk = false
				filter.filterHeaders(response: self) {
					result in
					switch result {
					case .continue:
						()
					case .done, .halt:
						brk = true
					}
				}
				if brk {
					break
				}
			}
		}
		
		let headers = HTTPHeaders(headerStore.map { ($0.0.standardName, $0.1) })
		let nstatus = NIOHTTP1.HTTPResponseStatus(statusCode: status.code)
		return HTTPHead(status: nstatus, headers: headers)
	}
	public override func body(promise: EventLoopPromise<IOData?>, allocator: ByteBufferAllocator) {
		if let p = proxy {
			promise.futureResult.whenSuccess { if $0 == nil { self.proxy = nil } }
			return p.body(promise: promise, allocator: allocator)
		}
		if let pcb = pushCallback {
			pushCallback = nil
			if hasCompleted {
				request.scratchPad["_flushing_"] = true
			}
			
			for filterSet in responseFilters {
				for filter in filterSet {
					var brk = false
					filter.filterBody(response: self) {
						result in
						switch result {
						case .continue:
							()
						case .done, .halt:
							brk = true
						}
					}
					if brk {
						break
					}
				}
			}
			
			// push/completed has been called
			if !bodyBytes.isEmpty {
				var b = allocator.buffer(capacity: bodyBytes.count)
				b.writeBytes(bodyBytes)
				bodyBytes.removeAll()
				promise.futureResult.whenSuccess { _ in pcb(true) }
				promise.futureResult.whenFailure { _ in pcb(false) }
				promise.succeed(.byteBuffer(b))
			} else if hasCompleted {
				promise.succeed(nil)
				pcb(true)
			} else {
				// no data but push was called
				// wait for another push/completed
				bodyPromise = promise
				bodyAllocator = allocator
				pcb(true)
			}
		} else if hasCompleted {
			promise.succeed(nil)
		} else {
			// wait for push/completed
			bodyPromise = promise
			bodyAllocator = allocator
		}
	}
	public func push(callback: @escaping (Bool) -> ()) {
		if nil == requestP {
			return callback(false)
		}
		pushCallback = callback
		if let hp = headPromise {
			// head has not been sent yet
			headPromise = nil
			// body will be called to finish up
			hp.succeed(self)
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
	
	public func header(_ named: HTTPResponseHeader.Name) -> String? {
		for (n, v) in headerStore where n == named {
			return v
		}
		return nil
	}
	@discardableResult
	public func addHeader(_ name: HTTPResponseHeader.Name, value: String) -> Self {
		headerStore.append((name, value))
		if case .contentLength = name {
//			contentLengthSet = true
		}
		return self
	}
	@discardableResult
	public func setHeader(_ name: HTTPResponseHeader.Name, value: String) -> Self {
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
	public func next() {
		if let n = handlers?.next() {
			n(request, self)
		} else {
			completed()
		}
	}
	public func completed() {
		guard !hasCompleted else {
			return
		}
		hasCompleted = true
		push { [weak self]
			_ in
			self?.closed()
		}
	}
}
