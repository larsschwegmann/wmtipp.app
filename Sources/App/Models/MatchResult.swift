//
//  MatchResult.swift
//  App
//
//  Created by Lars Schwegmann on 10.05.18.
//

import Vapor
import FluentPostgreSQL

final class MatchResult: PostgreSQLModel {
    var id: Int?
    var openLigaId: Int?
    
    var matchId: Match.ID
    
    var pointsTeam1: Int
    var pointsTeam2: Int
    
    var description: String
    var name: String
    
    var orderId: Int?
    var typeId: Int?
    
    init(id: Int? = nil, openLigaId: Int? = nil, matchId: Match.ID, pointsTeam1: Int, pointsTeam2: Int, description: String, name: String, orderId: Int? = nil, typeId: Int? = nil) {
        self.id = id
        self.openLigaId = openLigaId
        self.matchId = matchId
        self.pointsTeam1 = pointsTeam1
        self.pointsTeam2 = pointsTeam2
        self.description = description
        self.name = name
        self.orderId = orderId
        self.typeId = typeId
    }
}

extension MatchResult {
    
    var match: Parent<MatchResult, Match> {
        return parent(\.matchId)
    }
    
}

extension MatchResult: Migration { }
extension MatchResult: Content { }
extension MatchResult: Parameter { }
