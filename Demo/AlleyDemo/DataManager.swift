//
//  DataManager.swift
//  AlleyDemo
//
//  Created by Aleksandar Vacić on 12/11/19.
//  Copyright © 2019 Radiant Tap. All rights reserved.
//

import Foundation
import Alley

final class DataManager: ObservableObject {
	@Published private(set) var zens: [String] = []

	private lazy var urlSession: URLSession = prepareSession()
}


private extension DataManager {
	func prepareSession() -> URLSession {
		let urlSessionConfiguration: URLSessionConfiguration = {
			let c = URLSessionConfiguration.default
			c.allowsCellularAccess = true
			c.httpCookieAcceptPolicy = .never
			c.httpShouldSetCookies = false
			c.requestCachePolicy = .reloadIgnoringLocalCacheData
			return c
		}()

		return URLSession(configuration: urlSessionConfiguration,
						  delegate: nil,
						  delegateQueue: nil)
	}

	func fetch() {
		let urlRequest = URLRequest(url: URL(string: "https://api.github.com/zen")!)

		urlSession.perform(urlRequest, maxRetries: 3) {
			[unowned self] dataResult in

			switch dataResult {
			case .success(let data):
				if let s = data.utf8StringRepresentation {
					self.zens.append(s)
				}

			case .failure(let networkError):
				print(networkError)
			}
		}
	}
}


private extension Data {
	var utf8StringRepresentation: String? {
		guard
			let str = String(data: self, encoding: .utf8)
		else { return nil }

		return str
	}
}