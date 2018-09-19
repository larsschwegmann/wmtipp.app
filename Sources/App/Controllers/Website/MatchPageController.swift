//
//  MatchPageController.swift
//  App
//
//  Created by Lars Schwegmann on 16.06.18.
//

import Vapor
import Authentication
import Fluent
import Leaf

struct MatchPageController: RouteCollection {
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware()).grouped(RedirectMiddleware<User>(path: "/login"))
        router.get("match", Match.parameter, use: matchPageHandler)
    }
    
    func matchPageHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Match.self).flatMap { match -> EventLoopFuture<View> in
            let userLoggedIn = try req.isAuthenticated(User.self)
            let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
            let user = try req.authenticated(User.self)?.convertToPublic()
            
            return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<View> in
                
                let locationFuture = try match.location.get(on: conn)
                let team1Future = try match.team1.get(on: conn)
                let team2Future = try match.team2.get(on: conn)
                let betsFuture = try Bet.getAllBets(for: match, con: req)
                
                return flatMap(to: View.self, locationFuture, team1Future, team2Future, betsFuture) { location, team1, team2, bets in
                    let matchView = Match.ScheduleView(id: match.id,
                                                       openLigaId: match.openLigaId,
                                                       lastUpdate: match.lastUpdate,
                                                       group: nil,
                                                       team1: team1,
                                                       team2: team2,
                                                       location: location,
                                                       date: match.date,
                                                       isFinished: match.isFinished,
                                                       viewerCount: match.viewerCount,
                                                       finalGoalsTeam1: match.finalGoalsTeam1,
                                                       finalGoalsTeam2: match.finalGoalsTeam2)
                    
                    if team1.name == "Platzhalter" || team2.name == "Platzhalter" {
                        throw Abort(.badRequest, reason: "Cant show match page for matches with Platzhalter Teams")
                    }
                    
                    //Calculate Expectancies
                    let (EW_1, EW_2) = match.calculateWinExpectancies(team1: team1, team2: team2)
                    
                    //Calculate tippverteilung
                    let (b1, b2, ges) = bets.reduce((0.0, 0.0, 0.0), { (acc, bet) in
                        guard let b1 = bet.bet.betTeam1, let b2 = bet.bet.betTeam2 else {
                            return acc
                        }
                        if b1 > b2 {
                            return (acc.0 + 1, acc.1, acc.2 + 1)
                        } else if b1 < b2 {
                            return (acc.0, acc.1 + 1, acc.2 + 1)
                        } else {
                            return (acc.0, acc.1, acc.2 + 1)
                        }
                    })
                    
                    var context = MatchPageContext(title: "Match",
                                                   userLoggedIn: userLoggedIn,
                                                   user: user,
                                                   showCookieMessage: showCookieMessage,
                                                   match: matchView,
                                                   bets: bets,
                                                   groupTable: nil,
                                                   EW_1: Int(EW_1 * 100),
                                                   EW_2: Int(EW_2 * 100),
                                                   T1: Int((b1 / ges) * 100),
                                                   T2: Int((b2 / ges) * 100),
                                                   U: Int(((ges - b1 - b2) / ges) * 100))
                    
                    if context.EW_1 + context.EW_2 != 100 {
                        context.EW_1 = 100 - context.EW_2
                    }
                    
                    if context.T1 + context.T2 + context.U != 100 {
                        context.T1 = 100 - ( context.T2 + context.U )
                    }
                    
                    if match.groupId == 1 {
                        //Get Grouptable
                        context.groupTable = try Group.computeGroupTable(team1.groupLetter, on: conn)
                    }
                    
                    return try req.view().render("match/match", context)
                }
            })
        }
    }
    
    struct MatchPageContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        
        var match: Match.ScheduleView
        var bets: [Bet.BetsMatchPageView]
        
        var groupTable: Future<[Group.GroupTableEntryView]>?
        
        var EW_1: Int
        var EW_2: Int
        
        var T1: Int
        var T2: Int
        var U: Int
        
        let currentDate = Date()
    }
}


