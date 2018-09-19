//
//  UserProfileController.swift
//  App
//
//  Created by Dimitri Tyan on 10.06.18.
//

import Vapor
import Leaf
import Fluent
import Authentication

struct UserProfileController: RouteCollection {
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware()).grouped(RedirectMiddleware<User>(path: "/login"))
        router.get("users", User.parameter, use: userProfileHandler)
    }
    
    func userProfileHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        
        return try req.parameters.next(User.self).flatMap({ (queriedUser) -> EventLoopFuture<View> in
            guard let userId = queriedUser.id else {
                throw Abort(.internalServerError, reason: "Invalid userId")
            }

            //\.id == 1 -> Gruppenphase
            
            return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<View> in
                return try conn.query(Group.self).filter(\.id == 1).first().flatMap({ group -> Future<View> in
                    guard let group = group else {
                        throw Abort(.internalServerError, reason: "Couldn't find group with id 1")
                    }
                    
                    return try group.matches.query(on: conn).join(field: \Bet.matchId, to: \Match.id).filter(Bet.self, \.userId == userId).alsoDecode(Bet.self).all().flatMap({ matchTuples -> EventLoopFuture<View> in
                        try matchTuples.map({ matchTuple -> Future<(Match.ScheduleView, Bet)> in
                            let match = matchTuple.0
                            let bet = matchTuple.1
                            
                            let scheduleViewFuture = try match.team1.get(on: conn).flatMap(to: Match.ScheduleView.self, { team1 in
                                return try match.team2.get(on: req).map(to: Match.ScheduleView.self, { team2 in
                                    return Match.ScheduleView(id: match.id,
                                                              openLigaId: match.openLigaId,
                                                              lastUpdate: match.lastUpdate,
                                                              group: group,
                                                              team1: team1,
                                                              team2: team2,
                                                              location: nil,
                                                              date: match.date,
                                                              isFinished: match.isFinished,
                                                              viewerCount: match.viewerCount,
                                                              finalGoalsTeam1: match.finalGoalsTeam1,
                                                              finalGoalsTeam2: match.finalGoalsTeam2)
                                })
                            })
                            
                            return scheduleViewFuture.map({ scheduleView -> (Match.ScheduleView, Bet) in
                                return (scheduleView, bet)
                            })
                        }).flatten(on: req).flatMap({ results -> Future<View> in
                            let entries = results.sorted(by: { (left, right) -> Bool in
                                return left.0.id! < right.0.id!
                            })
                            let matches = entries.map({ entry -> Match.ScheduleView in
                                return entry.0
                            })
                            let bets = entries.map({ entry -> Bet in
                                return entry.1
                            })
                            
                            return try Group.groupLetters.map({ groupLetter in
                                try Group.computeGroupTable(groupLetter, on: conn).flatMap({ groupTableEntries in
                                    return req.eventLoop.newSucceededFuture(result: groupTableEntries.sorted(by: { (g1, g2) -> Bool in
                                        if g1.score == g2.score {
                                            if g1.diff == g2.diff {
                                                return g1.goals > g2.goals
                                            } else {
                                                return g1.diff > g2.diff
                                            }
                                        } else {
                                            return g1.score > g2.score
                                        }
                                        
                                    }))
                                })
                            }).flatten(on: req).flatMap({ groupTableEntries -> Future<View> in
                                try conn.query(Team.self).filter(\.name != "Platzhalter").all().flatMap({ teams -> Future<View> in
                                    let context = UserProfileContext(title: queriedUser.username, userLoggedIn: userLoggedIn, user: user, showCookieMessage: showCookieMessage, queriedUser: queriedUser, matches: matches,
                                                                     teams: teams, bets: bets, currentDate: Date(), groupTables: groupTableEntries)
                                    return try req.view().render("user_profile", context)
                                })
                            })
                        })
                    })
                })
            })
        })
    }
    
    struct UserProfileContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        
        var queriedUser: User
        var matches: [Match.ScheduleView]
        var teams: [Team]
        var bets: [Bet]
        var currentDate: Date
        let groupLetters = Group.groupLetters
        let groupTables: [[Group.GroupTableEntryView]]
    }
    
    struct Ranking: Codable {
        let rank: Int
        let username: String
        let score: Int
    }
}
