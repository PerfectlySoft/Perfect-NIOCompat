//
//  Mustache.swift
//  PerfectLib
//
//  Created by Kyle Jessup on 7/7/15.
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
@_exported import PerfectMustache
import PerfectHTTPC
import Foundation

extension HTTPResponse {
	public func renderMustache(template: String, context values: [String: Any] = [String: Any]()) {
		let context = MustacheEvaluationContext(templatePath: template)
		let collector = MustacheEvaluationOutputCollector()
		context.extendValues(with: values)
		do {
			let d = try context.formulateResponse(withCollector: collector)
			self.setBody(string: d)
				.completed()
		} catch {
			self.setBody(string: "\(error)")
				.completed(status: .internalServerError)
		}
	}
}
