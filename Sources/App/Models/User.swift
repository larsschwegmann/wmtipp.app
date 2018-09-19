//
//  User.swift
//  App
//
//  Created by Lars Schwegmann on 11.05.18.
//

import Vapor
import FluentPostgreSQL
import Authentication

final class User: Codable {
    var id: Int?
    
    var firstName: String
    var lastName: String
    var username: String
    var email: String
    var password: String
    var isAdmin: Bool
    var champBet: Team.ID?
    
    init(id: Int? = nil, firstName: String, lastName: String, username: String, email: String, password: String, isAdmin: Bool = false, champBet: Team.ID? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.password = password
        self.isAdmin = isAdmin
        self.champBet = champBet
    }
    
    final class Public: Codable {
        var id: Int?
        var firstName: String
        var lastName: String
        var username: String
        var isAdmin: Bool
        var champBet: Team.ID?
        
        init(id: Int? = nil, firstName: String, lastName: String, username: String, isAdmin: Bool = false, champBet: Team.ID? = nil) {
            self.id = id
            self.firstName = firstName
            self.lastName = lastName
            self.username = username
            self.isAdmin = isAdmin
            self.champBet = champBet
        }
    }
}

//MARK: Foreign Keys

extension User {
    var bets: Children<User, Bet> {
        return children(\.userId)
    }
}

//MARK: Fluent + Vapor protocol conformance

extension User: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            try builder.addIndex(to: \.email, isUnique: true)
            try builder.addIndex(to: \.username, isUnique: true)
        }
    }
}

extension User: PostgreSQLModel { }
extension User: Content { }
extension User.Public: Content { }
extension User: Parameter { }

//MARK: Private / Public Account logic

extension User {
    func convertToPublic() -> User.Public {
        return User.Public(id: self.id, firstName: self.firstName, lastName: self.lastName, username: self.username, isAdmin: self.isAdmin, champBet: self.champBet)
    }
}

extension Future where T: User {
    func convertToPublic() -> Future<User.Public> {
        return self.map(to: User.Public.self) { user in
            return user.convertToPublic()
        }
    }
}

//MARK: Authentication logic

extension User: PasswordAuthenticatable {
    static let usernameKey: WritableKeyPath<User, String> = \.email
    static let passwordKey: WritableKeyPath<User, String> = \.password
}

extension User: TokenAuthenticatable {
    typealias TokenType = Token
}

extension User: BasicAuthenticatable { }
extension User: SessionAuthenticatable { }
