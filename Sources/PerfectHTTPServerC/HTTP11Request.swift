//
//  HTTP11Request.swift
//  PerfectHTTPServerC
//
//  Created by Kyle Jessup on 2019-02-14.
//

import Foundation
import PerfectHTTPC
import PerfectNIO
import PerfectLib

import protocol PerfectHTTPC.HTTPRequest
import enum PerfectHTTPC.HTTPMethod

public final class HTTP11Request: HTTPRequest {
	var masterP: PerfectNIO.HTTPRequest?
	public var master: PerfectNIO.HTTPRequest { return masterP! }
	
	public var method: HTTPMethod {
		return master.method.compat
	}
	public let path: String
	public var pathComponents: [String] { return ["/"] + path.split(separator: "/").map(String.init) }
	public var queryParams: [(String, String)] {
		guard let qd = master.searchArgs else {
			return []
		}
		return qd.map { $0 }
	}
	public var protocolVersion: (Int, Int) = (1, 1)
	
	private func addrTup(_ addr: SocketAddress) -> (String, UInt16) {
		switch addr {
		case .v4(let v4):
			return (v4.host, UInt16(addr.port ?? 0))
		case .v6(let v6):
			return (v6.host, UInt16(addr.port ?? 0))
		case .unixDomainSocket(let u):
			return ("\(u)", 0)
		}
	}
	public var remoteAddress: (host: String, port: UInt16) {
		guard let addr = master.remoteAddress else {
			return ("", 0)
		}
		return addrTup(addr)
	}
	public var serverAddress: (host: String, port: UInt16) {
		guard let addr = master.localAddress else {
			return ("", 0)
		}
		return addrTup(addr)
	}
	public var serverName: String = ""
	public var documentRoot: String = "./webroot"
	public var urlVariables: [String : String] = [:]
	public var scratchPad: [String : Any] = [:]
	
	public var headers: AnyIterator<(HTTPRequestHeader.Name, String)> {
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
	
	public lazy var postParams: [(String, String)] = {
		if let mime = mimes {
			return mime.bodySpecs.filter { $0.file == nil }.map { ($0.fieldName, $0.fieldValue) }
		} else if let qd = postQueryDecoder {
			return qd.map { $0 }
		}
		return [(String, String)]()
	}()
	public var postBodyBytes: [UInt8]? {
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
	public var postBodyString: String? {
		guard let bytes = postBodyBytes else {
			return nil
		}
		if bytes.isEmpty {
			return ""
		}
		return UTF8Encoding.encode(bytes: bytes)
	}
	public var postFileUploads: [MimeReader.BodySpec]? {
		guard let mimes = self.mimes else {
			return nil
		}
		return mimes.bodySpecs
	}
	
	init(master: PerfectNIO.HTTPRequest, path: String) {
		self.masterP = master
		self.path = path.hasPrefix("/") ? path : ("/" + path)
	}
	deinit {
//		print("~HTTP11Request")
	}
	public func header(_ named: HTTPRequestHeader.Name) -> String? {
		return master.headers[named.standardName].first
	}
}
