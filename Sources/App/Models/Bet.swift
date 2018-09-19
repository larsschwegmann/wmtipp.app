//
//  Bet.swift
//  App
//
//  Created by Lars Schwegmann on 11.05.18.
//

import Vapor
import FluentPostgreSQL

final class Bet: PostgreSQLModel {
    var id: Int?
    
    var matchId: Match.ID
    var userId: User.ID
    
    var betTeam1: Int?
    var betTeam2: Int?
    
    var score: Int?
    
    init(id: Int? = nil, matchId: Match.ID, userId: User.ID, betTeam1: Int? = nil, betTeam2: Int? = nil, score: Int? = nil) {
        self.id = id
        self.matchId = matchId
        self.userId = userId
        self.betTeam1 = betTeam1
        self.betTeam2 = betTeam2
        self.score = score
    }
    
    func calculateScore(match: Match, user: User) {
        
        if let betTeam1 = self.betTeam1,
            let betTeam2 = self.betTeam2,
            let goalsTeam1 = match.finalGoalsTeam1,
            let goalsTeam2 = match.finalGoalsTeam2 {
            
            if betTeam1 == goalsTeam1 && betTeam2 == goalsTeam2 {
                self.score = 3
            } else if betTeam1 > betTeam2 && goalsTeam1 > goalsTeam2 {
                if betTeam1 - betTeam2 == goalsTeam1 - goalsTeam2 {
                    self.score = 2
                } else {
                    self.score = 1
                }
            } else if betTeam1 < betTeam2 && goalsTeam1 < goalsTeam2 {
                if betTeam1 - betTeam2 == goalsTeam1 - goalsTeam2 {
                    self.score = 2
                } else {
                    self.score = 1
                }
            } else if betTeam1 == betTeam2 && goalsTeam1 == goalsTeam2 {
                self.score = 2
            } else {
                self.score = 0
            }
        }
        
        //TODO: Remove hardcoded value
        if match.id == 64 && user.champBet == match.winner {
            if let prevScore = self.score, prevScore != 10 {
                self.score = prevScore + 10
            } else {
                self.score = 10
            }
        }
    }
    
    struct BetsMatchPageView: Codable {
        var bet: Bet
        var user: User.Public
        var rank: Scoreboard.RankingView
    }
}

extension Bet {
    var match: Parent<Bet, Match> {
        return parent(\.matchId)
    }
    
    var user: Parent<Bet, User> {
        return parent(\.userId)
    }
}

extension Bet {
    
    //Helper Methods
    
    static func createEmptyBets(for user: User, on conn: DatabaseConnectable) -> Future<[Bet]> {
        return Match.query(on: conn).all().flatMap { matches -> Future<[Bet]> in
            return matches.map({ match -> Future<Bet> in
                let bet = Bet(matchId: match.id!, userId: user.id!)
                return bet.save(on: conn)
            }).flatten(on: conn)
        }
    }
    
    static func scoreBets(match: Match, conn: PostgreSQLConnection) throws -> Future<[Bet]> {
        return try conn.query(Bet.self).filter(\.matchId == match.id).join(field: \User.id, to: \.userId).alsoDecode(User.self).all().flatMap { betsAndUsers in
            return betsAndUsers.map({ betAndUser -> Future<Bet> in
                let bet = betAndUser.0
                let user = betAndUser.1
                bet.calculateScore(match: match, user: user)
                return bet.update(on: conn)
            }).flatten(on: conn)
        }
    }
    
    static func getAllBets(for match: Match, con: Container) throws -> Future<[Bet.BetsMatchPageView]> {
        return con.withPooledConnection(to: .psql) { conn -> EventLoopFuture<[Bet.BetsMatchPageView]> in
            return Scoreboard.getGlobalScoreboard(on: con).flatMap({ rankings -> EventLoopFuture<[Bet.BetsMatchPageView]> in
                return try conn.query(Bet.self).filter(\.matchId == match.id!).join(User.self, field: \.id, to: \.userId).alsoDecode(User.self).all().map({ betUserTuples -> [Bet.BetsMatchPageView] in
                    return betUserTuples.map({ tuple -> Bet.BetsMatchPageView in
                        return BetsMatchPageView(bet: tuple.0, user: tuple.1.convertToPublic(), rank: rankings.first(where:{ranking in
                            return ranking.userId == tuple.1.id!
                        })!)
                    }).sorted(by: { (lhs, rhs) -> Bool in
                        return lhs.rank.rank < rhs.rank.rank
                    })
                })
            })
        }
    }
}

extension Bet: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            try builder.addIndex(to: \.matchId, \.userId, isUnique: true)
            try builder.addReference(from: \.matchId, to: \Match.id)
            try builder.addReference(from: \.userId, to: \User.id)
        }
    }
}
extension Bet: Content { }
extension Bet: Parameter { }
