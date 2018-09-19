//
//  LoginPageController.swift
//  App
//
//  Created by Lars Schwegmann on 08.06.18.
//

import Vapor
import Fluent
import Leaf
import Authentication

struct LoginPageController: RouteCollection {
    
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware())
        router.get("login", use: loginHandler)
        router.post(LoginPostData.self, at: "login", use: loginPostHandler)
        
        let authenticatedRoutes = router.grouped(RedirectMiddleware<User>(path: "/login"))
        authenticatedRoutes.get("logout", use: lougoutHandler)
    }
    
    func loginHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)
        let error = try req.session()["error"]
        try req.session()["error"] = nil
        
        let csrf = try CryptoRandom().generateData(count: 16).base64EncodedString()
        try req.session()["csrf"] = csrf
        
        return try req.view().render("login", LoginContext(title: "Login", userLoggedIn: userLoggedIn, user: user?.convertToPublic(), showCookieMessage: showCookieMessage, error: error, csrf: csrf))
    }
    
    func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
        let expectedCsrf = try req.session()["csrf"]
        if userData.csrf != expectedCsrf {
            try req.session()["error"] = "CSRF Token mismatch"
            return req.eventLoop.newSucceededFuture(result: req.redirect(to: "/login"))
        }
        
        if userData.email.contains("@") {
            return User.authenticate(username: userData.email, password: userData.password, using: BCryptDigest(), on: req).map(to: Response.self) { user in
                guard let user = user else {
                    try req.session()["error"] = "Wir konnten keinen Benutzer mit diesen Daten finden"
                    return req.redirect(to: "/login")
                }
                try req.authenticateSession(user)
                return req.redirect(to: "/")
            }
        } else {
            return req.withPooledConnection(to: .psql) { conn -> EventLoopFuture<Response> in
                return try User.query(on: conn).filter(\.username == userData.email).first().flatMap(to: Response.self) { user in
                    guard let user = user else {
                        try req.session()["error"] = "Wir konnten keinen Benutzer mit diesen Daten finden"
                        return req.eventLoop.newSucceededFuture(result: req.redirect(to: "/login"))
                    }
                    return User.authenticate(username: user.email, password: userData.password, using: BCryptDigest(), on: req).map(to: Response.self) { user in
                        guard let user = user else {
                            try req.session()["error"] = "Wir konnten keinen Benutzer mit diesen Daten finden"
                            return req.redirect(to: "/login")
                        }
                        try req.authenticateSession(user)
                        return req.redirect(to: "/")
                    }
                }
            }
        }
    }
    
    func lougoutHandler(_ req: Request) throws -> Response {
        try req.unauthenticateSession(User.self)
        return req.redirect(to: "/")
    }
    
    //MARK: - Page context structs
    
    struct LoginContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        var error: String?
        var csrf: String
    }
    
    //MARK: - POST Data structs
    
    struct LoginPostData: Content {
        let email: String
        let password: String
        let csrf: String
    }
}
