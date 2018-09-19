//
//  Community.swift
//  App
//
//  Created by Lars Schwegmann on 11.05.18.
//

import Vapor
import FluentPostgreSQL

final class Community: PostgreSQLModel {
    var id: Int?
    
    var name: String
    
    init(id: Int? = nil, name: String) {
        self.name = name
    }
}

extension Community {
    var members: Siblings<Community, User, CommunityUserPivot> {
        return siblings()
    }
}

extension Community: Migration { }
extension Community: Content { }
extension Community: Parameter { }
