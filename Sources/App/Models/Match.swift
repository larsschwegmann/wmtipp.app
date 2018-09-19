//
//  Match.swift
//  App
//
//  Created by Lars Schwegmann on 10.05.18.
//

import Foundation
import Vapor
import FluentPostgreSQL

final class Match: PostgreSQLModel, Codable {
    static let entity = "matches"
    
    static let firstMatchDate: Date = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return dateFormatter.date(from: "2018-06-14 17:00")!
    }()
    
    var id: Int?
    var openLigaId: Int
    var lastUpdate: Date?
    
    var groupId: Group.ID
    var team1Id: Team.ID
    var team2Id: Team.ID
    
    var locationId: Location.ID
    
    var date: Date
    var isFinished: Bool
    var viewerCount: Int?
    
    var finalGoalsTeam1: Int?
    var finalGoalsTeam2: Int?
        
    init(id: Int? = nil, openLigaId: Int, groupId: Group.ID, team1Id: Team.ID, team2Id: Team.ID, locationId: Location.ID, date: Date, isFinished: Bool, viewerCount: Int? = nil, goals: [Goal]? = nil, results: [MatchResult]? = nil, lastUpdate: Date? = nil, finalScoreTeam1: Int? = nil, finalScoreTeam2: Int? = nil) {
        self.id = id
        self.openLigaId = openLigaId
        self.groupId = groupId
        self.team1Id = team1Id
        self.team2Id = team2Id
        self.locationId = locationId
        self.date = date
        self.isFinished = isFinished
        self.viewerCount = viewerCount
        self.lastUpdate = lastUpdate
        self.finalGoalsTeam1 = finalScoreTeam1
        self.finalGoalsTeam2 = finalScoreTeam2
    }
    
    struct ScheduleView: Codable {
        var id: Int?
        var openLigaId: Int
        var lastUpdate: Date?
        
        var group: Group? //Made this optional because in the admin panel we don't need the group
        var team1: Team
        var team2: Team
        
        var location: Location?
        
        var date: Date
        var isFinished: Bool
        var viewerCount: Int?
        
        var finalGoalsTeam1: Int?
        var finalGoalsTeam2: Int?
    }
    
    struct IndexView: Codable {
        var id: Int?
        var openLigaId: Int
        var lastUpdate: Date?
        
        var team1: Team
        var team2: Team
        
        var date: Date
        var isFinished: Bool
        
        var goalsTeam1: Int?
        var goalsTeam2: Int?
        
        var bet: Bet? = nil
    }
}

extension Match {
    
    var goals: Children<Match, Goal> {
        return children(\.matchId)
    }
    
    var results: Children<Match, MatchResult> {
        return children(\.matchId)
    }
    
    var group: Parent<Match, Group> {
        return parent(\.groupId)
    }
    
    var team1: Parent<Match, Team> {
        return parent(\.team1Id)
    }
    
    var team2: Parent<Match, Team> {
        return parent(\.team2Id)
    }
    
    var location: Parent<Match, Location> {
        return parent(\.locationId)
    }
    
    var bets: Children<Match, Bet> {
        return children(\.matchId)
    }
    
    var goalDifference: Int? {
        guard let g1 = finalGoalsTeam1, let g2 = finalGoalsTeam2 else {
            return nil
        }
        return g1 - g2
    }
    
    var absGoalDifference: Int? {
        guard let diff = goalDifference else {
            return nil
        }
        return abs(diff)
    }
    
    var winner: Team.ID? {
        guard finalGoalsTeam1 != finalGoalsTeam2,
            let goalsTeam1 = finalGoalsTeam1,
            let goalsTeam2 = finalGoalsTeam2 else {
            return nil
        }
        
        return goalsTeam1 > goalsTeam2 ? team1Id : team2Id
    }
    
    var looser: Team.ID? {
        guard finalGoalsTeam1 != finalGoalsTeam2,
            let goalsTeam1 = finalGoalsTeam1,
            let goalsTeam2 = finalGoalsTeam2 else {
                return nil
        }
        
        return goalsTeam1 < goalsTeam2 ? team1Id : team2Id
    }
}

extension Match {
    var scoreTeam1: Int {
        guard let finalGoalsTeam1 = finalGoalsTeam1, let finalGoalsTeam2 = finalGoalsTeam2 else {
            return 0
        }
        return finalGoalsTeam1 > finalGoalsTeam2 ? 3 : (finalGoalsTeam2 > finalGoalsTeam1 ? 0 : 1)
    }
    
    var scoreTeam2: Int {
        guard let finalGoalsTeam1 = finalGoalsTeam1, let finalGoalsTeam2 = finalGoalsTeam2 else {
            return 0
        }
        return finalGoalsTeam2 > finalGoalsTeam1 ? 3 : (finalGoalsTeam1 > finalGoalsTeam2 ? 0 : 1)
    }
}

extension Match {
    
    func calculateWinExpectancies(team1: Team, team2: Team) -> (team1: Double, team2: Double) {
        let dr_1 = team1.elo - team2.elo
        let dr_2 = team2.elo - team1.elo
        return (team1:  1 / (pow(10.0, Double(-dr_1)/400) + 1), team2: 1 / (pow(10.0, Double(-dr_2)/400) + 1))
    }
    
    func calculateNewElo(team1: Team, team2: Team) {
        //http://www.eloratings.net/about
        guard let absDiff = absGoalDifference, self.isFinished else {
            return
        }
        
        let R0_1 = team1.elo
        let R0_2 = team2.elo
        var K: Double = 60
        
        
        
        switch absDiff {
        case 2:
            K += 0.5 * K
        case 3:
            K += 0.75 * K
        case 4...:
            K += (0.75 + (Double(absDiff) - 3.0)/8.0) * K
        default:
            break
        }
        
        let (We_1, We_2) = calculateWinExpectancies(team1: team1, team2: team2)
        
        guard let diff = goalDifference else {
            return
        }
        
        team1.elo = Int(Double(R0_1) + K * ((diff > 0 ? 1 : (diff == 0 ? 0.5 : 0)) - We_1))
        team2.elo = Int(Double(R0_2) + K * ((diff < 0 ? 1 : (diff == 0 ? 0.5 : 0)) - We_2))
    }
    
    func updateElos(on conn: DatabaseConnectable) throws -> Future<Void> {
        guard self.isFinished else {
            return Future.map(on: conn, {})
        }
        let team1Future = try self.team1.get(on: conn)
        let team2Future = try self.team2.get(on: conn)
        
        return flatMap(to: Void.self, team1Future, team2Future) { team1, team2 in
            self.calculateNewElo(team1: team1, team2: team2)
            
            return map(to: Void.self, team1.update(on: conn), team2.update(on: conn), { _, _ in })
        }
    }
}

extension Match {
    
    func updateFromOpenLigaDB(_ openLigaMatch: OpenLigaMatch, conn: PostgreSQLConnection) throws -> Future<Match> {
        guard let lastUpdate = self.lastUpdate,
            let openLigaLastUpdate = OpenLigaMatch.dateFormatter.date(from: String(openLigaMatch.LastUpdateDateTime.split(separator: ".")[0])),
            openLigaLastUpdate > lastUpdate else {
            return conn.eventLoop.newSucceededFuture(result: self)
        }
        
        if let date = OpenLigaMatch.dateFormatter.date(from: openLigaMatch.MatchDateTime) {
            self.date = date
        }
        
        let wasFinished = self.isFinished
        
        self.isFinished = openLigaMatch.MatchIsFinished
        self.viewerCount = openLigaMatch.NumberOfViewers
        
        let latestResult = openLigaMatch.MatchResults.max(by: { $0.ResultOrderID < $1.ResultOrderID })
        
        self.finalGoalsTeam1 = latestResult?.PointsTeam1
        self.finalGoalsTeam2 = latestResult?.PointsTeam2
        
        self.lastUpdate = openLigaLastUpdate
        
        let matchResults = try MatchResult.query(on: conn).filter(\.matchId == self.id).delete().flatMap({ _ -> EventLoopFuture<[MatchResult]> in
            return openLigaMatch.MatchResults.map {
                return MatchResult(openLigaId: $0.ResultID, matchId: self.id!, pointsTeam1: $0.PointsTeam1, pointsTeam2: $0.PointsTeam2, description: $0.ResultDescription, name: $0.ResultName, orderId: $0.ResultOrderID, typeId: $0.ResultTypeID).create(on: conn)
                }.flatten(on: conn)
        })
        
        let goals = try Goal.query(on: conn).filter(\.matchId == self.id).delete().flatMap({ _ -> EventLoopFuture<[Goal]> in
            return openLigaMatch.Goals.map({
                return Goal(openLigaId: $0.GoalID, matchId: self.id!, goalGetterName: $0.GoalGetterName, isOwnGoal: $0.IsOwnGoal, isPenalty: $0.IsPenalty, matchMinute: $0.MatchMinute, scoreTeam1: $0.ScoreTeam1, scoreTeam2: $0.ScoreTeam2).create(on: conn)
            }).flatten(on: conn)
        })
        
        let updateElos = wasFinished ? Future.map(on: conn, {}) : try self.updateElos(on: conn)
        
        return map(to: Match.self, matchResults, self.save(on: conn), updateElos, goals, { _, _, _, _ in
            return self
        })
    }
    
    static func updateRunningMatchesFromOpenLigaDB(on conn: PostgreSQLConnection, client: Client) throws -> Future<Void> {
        let currentDate = Date()
        
        return try conn.query(Match.self).filter(\.date <= currentDate).filter(\.isFinished == false).all().flatMap{ matches in
            //All Matches that have begun and are not finished yet
            return matches.map({ match in
                //Map each match to an openliga match and query openliga for it
                let endpoint = OpenLigaService.getSingleMatchData(matchId: match.openLigaId)
                let result = client.get(endpoint.baseURL.appendingPathComponent(endpoint.path))
                
                return result.flatMap({ result in
                    return try result.content.decode(OpenLigaMatch.self)
                }).flatMap({ openLigaMatch in
                    return try match.updateFromOpenLigaDB(openLigaMatch, conn: conn)
                }).flatMap({ match in
                    return try Bet.scoreBets(match: match, conn: conn)
                }).transform(to: ())
            }).flatten(on: conn)
        }
    }
    
    static func matchesOn(_ date: Date, on conn: PostgreSQLConnection, user: User?) throws -> Future<[Match.IndexView]> {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)
        if let user = user {
            return try Match.query(on: conn).filter(\.date >= startDate).filter(\.date <= endDate).join(Bet.self, field: \Bet.matchId, to: \Match.id, method: .outer).filter(Bet.self, \Bet.userId == user.id).alsoDecode(Bet.self).sort(\Match.id).all().flatMap({ matchTuples in
                return try matchTuples.map({ matchTuple -> Future<IndexView> in
                    let match = matchTuple.0
                    let bet = matchTuple.1
                    return try match.team1.query(on: conn).first().flatMap({team1 -> Future<IndexView> in
                        return try match.team2.query(on: conn).first().map({team2 -> IndexView in
                            return Match.IndexView(id: matchTuple.0.id, openLigaId: match.openLigaId, lastUpdate: match.lastUpdate, team1: team1!, team2: team2!, date: match.date, isFinished: match.isFinished, goalsTeam1: match.finalGoalsTeam1, goalsTeam2: match.finalGoalsTeam2, bet: bet)
                        })
                    })
                }).flatten(on: conn)
            })
        } else {
            return try Match.query(on: conn).filter(\.date >= startDate).filter(\.date <= endDate).sort(\Match.id).all().flatMap({ matches in
                return try matches.map({ match -> Future<IndexView> in
                    return try match.team1.query(on: conn).first().flatMap({team1 -> Future<IndexView> in
                        return try match.team2.query(on: conn).first().map({team2 -> IndexView in
                            return Match.IndexView(id: match.id, openLigaId: match.openLigaId, lastUpdate: match.lastUpdate, team1: team1!, team2: team2!, date: match.date, isFinished: match.isFinished, goalsTeam1: match.finalGoalsTeam1, goalsTeam2: match.finalGoalsTeam2, bet: nil)
                        })
                    })
                }).flatten(on: conn)
            })
        }
        
    }
    
    static func todaysMatches(on conn: PostgreSQLConnection, user: User?) throws -> Future<[Match.IndexView]> {
        return try matchesOn(Date(), on: conn, user: user)
    }
    
}

extension Match: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            try builder.addIndex(to: \.groupId, isUnique: false)
            try builder.addIndex(to: \.team1Id, isUnique: false)
            try builder.addIndex(to: \.team2Id, isUnique: false)
            try builder.addReference(from: \.team1Id, to: \Team.id)
            try builder.addReference(from: \.team2Id, to: \Team.id)
        }
    }
}

extension Match: Content { }
extension Match: Parameter { }
