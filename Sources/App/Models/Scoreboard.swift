//
//  Scoreboard.swift
//  App
//
//  Created by Lars Schwegmann on 12.06.18.
//

import Vapor
import FluentPostgreSQL

final class Scoreboard: PostgreSQLModel {
    static let entity = "scoreboard"
    
    var id: Int?
    var userId: User.ID
    var date: Date
    var rank: Int
    
    init(id: Int? = nil, userId: User.ID, date: Date, rank: Int) {
        self.id = id
        self.userId = userId
        self.date = date
        self.rank = rank
    }
}

extension Scoreboard {
    
    static func getGlobalScoreboard(on con: Container) -> Future<[RankingView]> {
        return con.withPooledConnection(to: .psql) { conn -> Future<[RankingView]> in
            conn.query("""
                    SELECT users.id, users.username, users."firstName", users."lastName", COALESCE(ranks.rank, -1) AS prev_rank, COALESCE(SUM(score), 0) AS score
                    FROM bets
                    INNER JOIN users ON bets."userId" = users.id
                    LEFT JOIN (
                            SELECT DISTINCT ON ("userId") *
                            FROM scoreboard
                            ORDER BY "userId", date DESC NULLS LAST
                        ) AS ranks ON ranks."userId" = users.id
                    GROUP BY users.id, users."firstName", users."lastName", users.username, prev_rank
                    ORDER BY score desc
                    """).map({ scoreData in
                
                var rankCounter = 1
                var oldRank = 1
                var oldScore = 0
                
                var rankings: [RankingView] = []
                
                try scoreData.forEach() { data in
                    guard let userName = try data.firstValue(forColumn: "username")?.decode(String.self),
                        let firstName = try data.firstValue(forColumn: "firstName")?.decode(String.self),
                        let lastName = try data.firstValue(forColumn: "lastName")?.decode(String.self),
                        let scoreString = try data.firstValue(forColumn: "score")?.decode(String.self),
                        let prevRank = try data.firstValue(forColumn: "prev_rank")?.decode(Int.self),
                        let userId = try data.firstValue(forColumn: "id")?.decode(Int.self) else {
                            throw Abort(.internalServerError)
                    }
                    
                    let score = Int(scoreString)
                    
                    var rank: Int
                    if score ?? 0 >= oldScore {
                        rank = oldRank
                        oldScore = score ?? 0
                    } else {
                        rank = rankCounter
                        oldRank = rankCounter
                        oldScore = score ?? 0
                    }
                    
                    rankCounter += 1
                    rankings += [RankingView(rank: rank, prevRank: prevRank, username: userName, firstName: firstName, lastName: lastName, userId: userId, score: score ?? 0)]
                }
                return rankings
            })
        }
    }
    
    struct RankingView: Codable {
        let rank: Int
        let prevRank: Int
        let username: String
        let firstName: String
        let lastName: String
        let userId: Int
        let score: Int
    }
}

extension Scoreboard: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            try builder.addIndex(to: \.userId, \.date, isUnique: true)
            try builder.addReference(from: \.userId, to: \User.id)
        }
    }
}

extension Scoreboard: Content { }
