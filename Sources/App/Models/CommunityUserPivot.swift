//
//  CommunityUserPivot.swift
//  App
//
//  Created by Lars Schwegmann on 11.05.18.
//

import Vapor
import FluentPostgreSQL

final class CommunityUserPivot: PostgreSQLPivot {
    var id: Int?
    
    var communityId: Community.ID
    var userId: User.ID
    
    static let leftIDKey: LeftIDKey = \.communityId
    
    static var rightIDKey: RightIDKey = \.userId
    
    typealias Left = Community
    
    typealias Right = User
    
    init(id: Int? = nil, communityId: Community.ID, userId: User.ID) {
        self.id = id
        self.communityId = communityId
        self.userId = userId
    }
}

extension CommunityUserPivot: Migration { }

