//
//  StaticFileHandler.swift
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

import Foundation
import PerfectLib
import PerfectMIME
import CNIOSHA1

extension String.UTF8View {
	var sha1: [UInt8] {
		let bytes = UnsafeMutablePointer<Int8>.allocate(capacity:  Int(SHA1_RESULTLEN))
		defer { bytes.deallocate() }
		let src = Array<UInt8>(self)
		var ctx = SHA1_CTX()
		c_nio_sha1_init(&ctx)
		c_nio_sha1_loop(&ctx, src, src.count)
		c_nio_sha1_result(&ctx, bytes)
		var r = [UInt8]()
		for idx in 0..<Int(SHA1_RESULTLEN) {
			r.append(UInt8(bitPattern: bytes[idx]))
		}
		return r
	}
}

extension UInt8 {
	// same as String(self, radix: 16)
	// but outputs two characters. i.e. 0 padded
	var hexString: String {
		let s = String(self, radix: 16)
		if s.count == 1 {
			return "0" + s
		}
		return s
	}
}

/// A web request handler which can be used to return static disk-based files to the client.
/// Supports byte ranges, ETags and streaming very large files.
public struct StaticFileHandler {
	
	let chunkedBufferSize = 1024*200
	let documentRoot: String
	
	/// Public initializer given a document root.
	/// If allowResponseFilters is false (which is the default) then the file will be sent in
	/// the most effecient way possible and output filters will be bypassed.
	public init(documentRoot: String, allowResponseFilters: Bool = false) {
		self.documentRoot = documentRoot
	}
	
	/// Main entry point. A registered URL handler should call this and pass the request and response objects.
	/// After calling this, the StaticFileHandler owns the request and will handle it until completion.
	public func handleRequest(request: HTTPRequest, response: HTTPResponse) {
		func fnf(msg: String) {
			response.status = .notFound
			response.appendBody(string: msg)
			// !FIX! need 404.html or some such thing
			response.completed()
		}
		var pathComponents = request.pathComponents
		if pathComponents.last == "/" {
			pathComponents.removeLast()
			pathComponents.append("index.html") // !FIX! needs to be configurable
		}
		if pathComponents.first == "/" {
			pathComponents.removeFirst()
		}
		let path = pathComponents.joined(separator: "/")
		guard let sanitized = sanitizePathTraversal(path) else {
			return fnf(msg: "The file /\(path) could not be opened.")
		}
		let file = File(documentRoot + "/" + sanitized)
		guard file.exists else {
			return fnf(msg: "The file /\(path) was not found.")
		}
		do {
			try file.open(.read)
			sendFile(request: request, response: response, file: file)
		} catch {
			return fnf(msg: "The file /\(path) could not be opened \(error).")
		}
	}
	// returns nil if the path is invalid
	func sanitizePathTraversal(_ path: String) -> String? {
		var ret: [String] = []
		for component in path.filePathComponents {
			switch component {
			case "", "/", ".": continue
			case "..":
				if ret.isEmpty { // invalid
					return nil
				}
				ret.removeLast()
			default:
				ret.append(component)
			}
		}
		return ret.joined(separator: "/")
	}
	
	func sendFile(request: HTTPRequest, response: HTTPResponse, file: File) {
		
		response.addHeader(.acceptRanges, value: "bytes")
		
		if let rangeRequest = request.header(.range) {
			return performRangeRequest(rangeRequest: rangeRequest, request: request, response: response, file: file)
		} else if let ifNoneMatch = request.header(.ifNoneMatch) {
			let eTag = getETag(file: file)
			if ifNoneMatch == eTag {
				response.status = .notModified
				return response.next()
			}
		}
		
		let size = file.size
		let contentType = MIMEType.forExtension(file.path.filePathExtension)
		
		response.status = .ok
		response.addHeader(.contentType, value: contentType)
		
//		if allowResponseFilters {
//			response.isStreaming = true
//		} else {
			response.addHeader(.contentLength, value: "\(size)")
//		}
		
		addETag(response: response, file: file)
		
		if case .head = request.method {
			return response.next()
		}
		
		// send out headers
		response.push { ok in
			guard ok else {
				file.close()
				return response.completed()
			}
			self.sendFile(remainingBytes: size, response: response, file: file) {
				ok in
				file.close()
				response.next()
			}
		}
	}
	
	func performRangeRequest(rangeRequest: String, request: HTTPRequest, response: HTTPResponse, file: File) {
		let size = file.size
		let ranges = parseRangeHeader(fromHeader: rangeRequest, max: size)
		if ranges.count == 1 {
			let range = ranges[0]
			let rangeCount = range.count
			let contentType = MimeType.forExtension(file.path.filePathExtension)
			
			response.status = .partialContent
			response.addHeader(.contentLength, value: "\(rangeCount)")
			response.addHeader(.contentType, value: contentType)
			response.addHeader(.contentRange, value: "bytes \(range.lowerBound)-\(range.upperBound-1)/\(size)")
			
			if case .head = request.method {
				return response.next()
			}
			
			file.marker = range.lowerBound
			// send out headers
			response.push { ok in
				guard ok else {
					file.close()
					return response.completed()
				}
				return self.sendFile(remainingBytes: rangeCount, response: response, file: file) {
					ok in
					
					file.close()
					response.next()
				}
			}
		} else if ranges.count > 0 {
			// !FIX! support multiple ranges
			response.status = .internalServerError
			return response.completed()
		} else {
			response.status = .badRequest
			return response.completed()
		}
	}
	
	func getETag(file: File) -> String {
		let eTagStr = file.path + "\(file.modificationTime)"
		let eTag = eTagStr.utf8.sha1
		let eTagReStr = eTag.map { $0.hexString }.joined(separator: "")
		return eTagReStr
	}
	
	func addETag(response: HTTPResponse, file: File) {
		let eTag = getETag(file: file)
		response.addHeader(.eTag, value: eTag)
	}
	
	func sendFile(remainingBytes remaining: Int, response: HTTPResponse, file: File, completion: @escaping (Bool) -> ()) {
		let thisRead = min(chunkedBufferSize, remaining)
		do {
			let bytes = try file.readSomeBytes(count: thisRead)
			response.appendBody(bytes: bytes)
			response.push {
				ok in
				
				if !ok || thisRead == remaining {
					// done
					completion(ok)
				} else {
					self.sendFile(remainingBytes: remaining - bytes.count, response: response, file: file, completion: completion)
				}
			}
		} catch {
			completion(false)
		}
	}
	
	// bytes=0-3/7-9/10-15
	func parseRangeHeader(fromHeader header: String, max: Int) -> [Range<Int>] {
		let initialSplit = header.split(separator: "=")
		guard initialSplit.count == 2 && String(initialSplit[0]) == "bytes" else {
			return [Range<Int>]()
		}
		let ranges = initialSplit[1]
		return ranges.split(separator: "/").compactMap { self.parseOneRange(fromString: String($0), max: max) }
	}
	
	// 0-3
	// 0-
	func parseOneRange(fromString string: String, max: Int) -> Range<Int>? {
		let split = string.split(separator: "-", omittingEmptySubsequences: false).map { String($0) }
		guard split.count == 2 else {
			return nil
		}
		if split[1].isEmpty {
			guard let lower = Int(split[0]),
				lower <= max else {
					return nil
			}
			return Range(uncheckedBounds: (lower, max))
		}
		guard let lower = Int(split[0]),
			let upperRaw = Int(split[1]) else {
				return nil
		}
		let upper = Swift.min(max, upperRaw+1)
		guard lower <= upper else {
			return nil
		}
		return Range(uncheckedBounds: (lower, upper))
	}
}
