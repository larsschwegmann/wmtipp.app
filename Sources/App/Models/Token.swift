//
//  Token.swift
//  Alamofire
//
//  Created by Lars Schwegmann on 20.05.18.
//

import Vapor
import FluentPostgreSQL
import Authentication

final class Token: Codable {
    var id: Int?
    var token: String
    var userId: User.ID
    
    init(id: Int? = nil, token: String, userId: User.ID) {
        self.id = id
        self.token = token
        self.userId = userId
    }
}

extension Token: PostgreSQLModel { }
extension Token: Migration { }
extension Token: Content { }

extension Token {
    static func generate(for user: User) throws -> Token {
        let random = try CryptoRandom().generateData(count: 16)
        return try Token(token: random.base64EncodedString(), userId: user.requireID())
    }
}

extension Token: Authentication.Token {
    static let userIDKey: UserIDKey = \Token.userId
    typealias UserType = User
}

extension Token: BearerAuthenticatable {
    static let tokenKey: TokenKey = \Token.token
}
