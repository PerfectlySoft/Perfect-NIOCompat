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

/// A web request handler which can be used to return static disk-based files to the client.
/// Supports byte ranges, ETags and streaming very large files.
public struct StaticFileHandler {
	
	let documentRoot: String
	let allowResponseFilters: Bool
	
	/// Public initializer given a document root.
	/// If allowResponseFilters is false (which is the default) then the file will be sent in
	/// the most effecient way possible and output filters will be bypassed.
	public init(documentRoot: String, allowResponseFilters: Bool = false) {
		self.documentRoot = documentRoot
		self.allowResponseFilters = allowResponseFilters
	}
	
	/// Main entry point. A registered URL handler should call this and pass the request and response objects.
	/// After calling this, the StaticFileHandler owns the request and will handle it until completion.
	public func handleRequest(request: HTTPRequest, response: HTTPResponse) {
	
	}
}
