//
//  HTTPContentCompression.swift
//  PerfectHTTPServer
//	Copyright (C) 2016 PerfectlySoft, Inc.
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

public extension HTTPFilter {
	/// Response filter which provides content compression.
	/// Mime types which will be encoded or ignored can be specified with the "compressTypes" and
	/// "ignoreTypes" keys, respectively. The values for these keys should be an array of String
	/// containing either the full mime type or the the main type with a * wildcard. e.g. text/*
	/// The default values for the compressTypes key are: "*/*"
	/// The default values for the ignoreTypes key are: "image/*", "video/*", "audio/*"
	public static func contentCompression(data: [String:Any]) throws -> HTTPResponseFilter {
		struct CompressResponse: HTTPResponseFilter {
			func filterHeaders(response: HTTPResponse, callback: (HTTPResponseFilterResult) -> ()) {
				return callback(.continue)
			}
			
			func filterBody(response: HTTPResponse, callback: (HTTPResponseFilterResult) -> ()) {
				return callback(.continue)
			}
		}
		return CompressResponse()
	}
}
