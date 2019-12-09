//
//  URLSession-extensions.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

extension URLSession {
	///	Default number of retries to attempt on each `URLRequest` instance. To customize, supply desired value to `perform()`
	static var maximumNumberOfRetries: Int = 10

	///	Output types
	typealias DataResult = Result<Data, NetworkError>
	typealias Callback = (DataResult) -> Void

	func perform(_ urlRequest: URLRequest,
				 maxRetries: Int = URLSession.maximumNumberOfRetries,
				 allowEmptyData: Bool = false,
				 callback: @escaping Callback)
	{
		if maxRetries <= 0 {
			fatalError("maxRetries must be 1 or larger.")
		}

		let networkRequest = NetworkRequest(urlRequest, 0, maxRetries, allowEmptyData, callback)
		authenticate(networkRequest)
	}
}

private extension URLSession {
	///	Helper type which models `URLRequest` (input), `Callback` from the callee (output)
	///	along with helpful processing properties, like number of retries.
	typealias NetworkRequest = (
		urlRequest: URLRequest,
		currentRetries: Int,
		maxRetries: Int,
		allowEmptyData: Bool,
		callback: Callback
	)

	///	Extra-step where `URLRequest`'s authorization should be handled, before actually performing the URLRequest in `execute()`
	func authenticate(_ networkRequest: NetworkRequest) {
		let currentRetries = networkRequest.currentRetries
		let max = networkRequest.maxRetries
		let callback = networkRequest.callback

		if currentRetries >= max {
			//	Too many unsuccessful attemps
			callback( .failure( .inaccessible ) )
		}

		//	NOTE: this is the place to handle OAuth2
		//	or some other form of URLRequest‘s authorization

		//	now execute the request
		execute(networkRequest)
	}

	///	Creates the instance of `URLSessionDataTask`, performs it then lightly processes the response before calling `validate`.
	func execute(_ networkRequest: NetworkRequest) {
		let urlRequest = networkRequest.urlRequest

		let task = dataTask(with: urlRequest) {
			[unowned self] data, urlResponse, error in

			let dataResult = self.process(data, urlResponse, error, for: networkRequest)
			self.validate(dataResult, for: networkRequest)
		}

		task.resume()
	}

	///	Process results of `URLSessionDataTask` and converts it into `DataResult` instance
	func process(_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?, for networkRequest: NetworkRequest) -> DataResult {
		let allowEmptyData = networkRequest.allowEmptyData

		if let urlError = error as? URLError {
			return .failure( NetworkError.urlError(urlError) )

		} else if let otherError = error {
			return .failure( NetworkError.generalError(otherError) )
		}

		guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
			if let urlResponse = urlResponse {
				return .failure( NetworkError.invalidResponseType(urlResponse) )
			} else {
				return .failure( NetworkError.noResponse )
			}
		}

		guard let data = data, data.count > 0 else {
			if allowEmptyData {
				return .success(Data())
			}

			return .failure( NetworkError.noResponseData(httpURLResponse) )
		}

		return .success(data)
	}

	///	Checks the result of URLSessionDataTask and if there were errors, should the URLRequest be retried.
	func validate(_ result: DataResult, for networkRequest: NetworkRequest) {
		let callback = networkRequest.callback

		switch result {
		case .success:
			break

		case .failure(let networkError):
			switch networkError {
			case .inaccessible:
				//	too many failed network calls
				break

			default:
				if networkError.shouldRetry {
					//	update retries count and
					var newRequest = networkRequest
					newRequest.currentRetries += 1
					//	try again, going through authentication again
					//	(since it's quite possible that Auth token or whatever has expired)
					self.authenticate(newRequest)
					return
				}
			}
		}

		callback(result)
	}
}
