//
//  RegisterPageController.swift
//  App
//
//  Created by Lars Schwegmann on 08.06.18.
//

import Vapor
import Leaf
import Fluent
import Authentication

import Authentication

struct RegisterPageController: RouteCollection {
    
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware())
        router.get("register", use: registerHandler)
        router.post(RegisterPostData.self, at: "register", use: registerPostHandler)
    }
    
    func registerHandler(_ req: Request) throws -> Future<View> {
        if try req.isAuthenticated(User.self) {
            throw Abort(.found, headers: ["Location": "/"])
        }
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)
        
        let error = try req.session()["error"]
        try req.session()["error"] = nil
        let firstName = try req.session()["firstName"]
        let lastName = try req.session()["lastName"]
        let username = try req.session()["username"]
        let email = try req.session()["email"]
        
        return try req.view().render("register", RegisterContext(title: "Registrieren", userLoggedIn: userLoggedIn, user: user?.convertToPublic(), showCookieMessage: showCookieMessage, firstName: firstName, lastName: lastName, username: username, email: email, error: error))
    }
    
    func registerPostHandler(_ req: Request, userData: RegisterPostData) throws -> Future<Response> {
        do {
            try userData.validate()
            
            if !userData.acceptDSGVO || !userData.acceptRules {
                throw BasicValidationError("Du musst die Datenschutzbestimmungen und die Regeln akzeptieren um dich zu Registrieren")
            }
        } catch {
            return Future.map(on: req) {
                try req.session()["error"] = error.localizedDescription
                try req.session()["firstName"] = userData.firstName
                try req.session()["lastName"] = userData.lastName
                try req.session()["username"] = userData.username
                try req.session()["email"] = userData.email
                return req.redirect(to: "/register")
            }
        }
        let password = try BCrypt.hash(userData.password)
        let user = User(firstName: userData.firstName, lastName: userData.lastName, username: userData.username, email: userData.email, password: password)
        return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<Response> in
            return user.save(on: conn).flatMap(to: Response.self, { user in
                Bet.createEmptyBets(for: user, on: conn).map(to: Response.self, { bets in
                    try req.authenticateSession(user)
                    return req.redirect(to: "/")
                })
            })
        })
        
    }
    
    //MARK: - Page context structs
    
    struct RegisterContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        
        let firstName: String?
        let lastName: String?
        let username: String?
        let email: String?
        
        var error: String?
    }
    
    //MARK: - POST Data structs
    
    struct RegisterPostData: Content, Validatable, Reflectable {
        let firstName: String
        let lastName: String
        let username: String
        let email: String
        let password: String
        let passwordRepeat: String
        let acceptDSGVO: Bool
        let acceptRules: Bool
        
        static func validations() throws -> Validations<RegisterPostData> {
            var validations = Validations(RegisterPostData.self)
            try validations.add(\.email, .email)
            try validations.add(\.username, .alphanumeric)
            try validations.add(\.password, .count(8...))
            
            validations.add("passwords match", { data in
                guard data.password == data.passwordRepeat else {
                    throw BasicValidationError("Passwörter stimmen nicht überein")
                }
            })
            return validations
        }
    }
}
