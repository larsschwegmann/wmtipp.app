//
//  Goal.swift
//  App
//
//  Created by Lars Schwegmann on 10.05.18.
//

import Vapor
import FluentPostgreSQL

final class Goal: PostgreSQLModel {
    var id: Int?
    var openLigaId: Int?
    
    var matchId: Match.ID
    
    var goalGetterId: Int?
    var goalGetterName: String?
    
    var comment: String?
    
    var isOwnGoal: Bool
    var isPenalty: Bool
    
    var matchMinute: Int?
    var scoreTeam1: Int
    var scoreTeam2: Int
    
    init(id: Int? = nil, openLigaId: Int? = nil, matchId: Match.ID, goalGetterId: Int? = nil, goalGetterName: String? = nil, comment: String? = nil, isOwnGoal: Bool, isPenalty: Bool, matchMinute: Int? = nil, scoreTeam1: Int, scoreTeam2: Int) {
        self.id = id
        self.openLigaId = openLigaId
        self.matchId = matchId
        self.goalGetterId = goalGetterId
        self.goalGetterName = goalGetterName
        self.comment = comment
        self.isOwnGoal = isOwnGoal
        self.isPenalty = isPenalty
        self.matchMinute = matchMinute
        self.scoreTeam1 = scoreTeam1
        self.scoreTeam2 = scoreTeam2
    }
}

extension Goal {
    var match: Parent<Goal, Match> {
        return parent(\.matchId)
    }
}

extension Goal: Migration { }
extension Goal: Content { }
extension Goal: Parameter { }
