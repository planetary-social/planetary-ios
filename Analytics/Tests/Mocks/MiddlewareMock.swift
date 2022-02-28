//
//  MiddlewareMock.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import PostHog

class MiddlewareMock: PHGMiddleware {
    var lastContext: PHGContext?
    func context(_ context: PHGContext, next: @escaping PHGMiddlewareNext) {
        lastContext = context
        next(context)
    }
}
