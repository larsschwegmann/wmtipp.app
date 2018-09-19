//
//  AdminCheckRedirectMiddleware.swift
//  App
//
//  Created by Lars Schwegmann on 10.06.18.
//

import Vapor
import Authentication

//Blatant copy of RedirectMiddleware.swift from the authentication librar

/// Basic middleware to redirect unauthenticated requests to the supplied path
struct AdminCheckRedirectMiddleware<A>: Middleware where A: User {
    
    /// The path to redirect to
    let path: String
    
    /// Initialise the `RedirectMiddleware`
    ///
    /// - parameters:
    ///    - authenticatableType: The type to check authentication against
    ///    - path: The path to redirect to if the request is not authenticated
    public init(A authenticatableType: A.Type = A.self, path: String) {
        self.path = path
    }
    
    /// See Middleware.respond
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        guard let user = try req.authenticated(User.self), user.isAdmin else {
            let redirect = req.redirect(to: path)
            return req.eventLoop.newSucceededFuture(result: redirect)
        }
        
        return try next.respond(to: req)
    }
    
    /// Use this middleware to redirect users away from
    /// protected content to a login page
    public static func login(path: String = "/login") -> AdminCheckRedirectMiddleware {
        return AdminCheckRedirectMiddleware(path: path)
    }
}

