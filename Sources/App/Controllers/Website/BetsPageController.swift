//
//  BetsPageController.swift
//  App
//
//  Created by Lars Schwegmann on 08.06.18.
//

import Vapor
import Fluent
import Leaf
import Authentication

struct BetsPageController: RouteCollection {
    
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware()).grouped(RedirectMiddleware<User>(path: "/login"))
        
        router.get("bets", use: { req -> Response in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let switchDate = dateFormatter.date(from: "2018-06-29")! //TODO: Remove magic number
            if Date() < switchDate {
                return req.redirect(to: "/bets/groups")
            } else {
                return req.redirect(to: "/bets/ko")
            }
        })
        
        router.get("bets/groups", use: betsGroupsHandler)
        router.post("bets/groups", use: betsGroupsPostHandler)
        
        router.get("bets/ko", use: betsKOPhaseHandler)
        router.post("bets/ko", use: betsKOPhasePostHandler)
    }
    
    func betsGroupsHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        let succesfulSave = req.query[Bool.self, at: "success"] != nil
        
        //\.id == 1 -> Gruppenphase
        
        return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<View> in
            return try conn.query(Group.self).filter(\Group.id == 1).first().flatMap({ group -> Future<View> in
                guard let group = group else {
                    throw Abort(.internalServerError, reason: "Couldn't find group with id 1")
                }
                
                return try group.matches.query(on: conn).join(field: \Bet.matchId, to: \Match.id).filter(Bet.self, \.userId == user!.id).alsoDecode(Bet.self).join(field: \Location.id, to: \Match.locationId).alsoDecode(Location.self).all().flatMap({ matchTuples -> EventLoopFuture<View> in
                    try matchTuples.map({ matchTuple -> Future<(Match.ScheduleView, Bet)> in
                        let match = matchTuple.0.0
                        let bet = matchTuple.0.1
                        let location = matchTuple.1
                        
                        let scheduleViewFuture = try match.team1.get(on: conn).flatMap(to: Match.ScheduleView.self, { team1 in
                            return try match.team2.get(on: conn).flatMap(to: Match.ScheduleView.self, { team2 in
                                return req.eventLoop.newSucceededFuture(result: Match.ScheduleView(id: match.id, openLigaId: match.openLigaId, lastUpdate: match.lastUpdate, group: group, team1: team1, team2: team2, location: location, date: match.date, isFinished: match.isFinished, viewerCount: match.viewerCount, finalGoalsTeam1: match.finalGoalsTeam1, finalGoalsTeam2: match.finalGoalsTeam2))
                            })
                        })
                        
                        return scheduleViewFuture.flatMap({ scheduleView -> Future<(Match.ScheduleView, Bet)> in
                            return req.eventLoop.newSucceededFuture(result: (scheduleView, bet))
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
                            try Team.query(on: conn).filter(\.name != "Platzhalter").all().flatMap({ teams -> Future<View> in
                                let context = BetsGroupContext(title: "Tippschein", userLoggedIn: userLoggedIn, user: user, showCookieMessage: showCookieMessage, group: group, matches: matches, teams: teams, bets: bets, champBet: user?.champBet, groupTables: groupTableEntries, successfulSave: succesfulSave, currentDate: Date(), firstMatchDate: Match.firstMatchDate)
                                return try req.view().render("bets/bets_groups", context)
                            })
                        })
                    })
                })
            })
        })
    }
    
    func betsGroupsPostHandler(_ req: Request) throws -> Future<Response> {
        let user = try req.authenticated(User.self)
        
        return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<Response> in
            let dataDictFuture = try req.content.decode(Dictionary<String, String>.self)
            let matchCountFuture = try Match.query(on: conn).filter(\.groupId == 1).all()
            
            return dataDictFuture.and(matchCountFuture).map { (dataDict, matches) -> [Bet] in
                //Check and Save Champ Bet
                if let champBetString = dataDict["champ_bet"], let champBet = Team.ID(champBetString), Date() < Match.firstMatchDate {
                    user?.champBet = champBet
                    let _ = user?.update(on: req)
                }
                
                //Save other bets
                return matches.compactMap({ match -> Bet? in
                    guard let betTeam1String = dataDict["team1_\(match.id!)"],
                        let betTeam2String = dataDict["team2_\(match.id!)"] else {
                            return nil
                    }
                    
                    let betTeam1 = Int(betTeam1String)
                    let betTeam2 = Int(betTeam2String)
                    
                    if Date() >= match.date {
                        return nil
                    }
                    
                    return Bet(matchId: match.id!, userId: user!.id!, betTeam1: betTeam1, betTeam2: betTeam2)
                })
                }.flatMap { bets -> Future<[Bet]> in
                    return try bets.map({ bet -> Future<Bet> in
                        return try conn.query(Bet.self).filter(\.matchId == bet.matchId).filter(\.userId == bet.userId).first().then({ dbBet in
                            if let dbBet = dbBet {
                                dbBet.betTeam1 = bet.betTeam1
                                dbBet.betTeam2 = bet.betTeam2
                                return dbBet.save(on: req)
                            } else {
                                return Bet(matchId: bet.matchId, userId: bet.userId, betTeam1: bet.betTeam1, betTeam2: bet.betTeam2).save(on: conn)
                            }
                        })
                    }).flatten(on: req)
                }.transform(to: req.redirect(to: "/bets/groups?success=true"))
        })
    }
    
    func betsKOPhaseHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        let successfulSave = try req.session()["success"] != nil
        try req.session()["success"] = nil
        
        return req.withPooledConnection(to: .psql) { conn -> Future<View> in
            let scheduleViews = try conn.query(Group.self)
                .filter(\Group.id > 1)
                .join(field: \Match.groupId, to: \Group.id)
                .alsoDecode(Match.self)
                .sort(QuerySort(field: QueryField(entity: "matches", name: "id"), direction: .ascending))
                .all().flatMap({groupsAndMatches in
                    return try groupsAndMatches.map({ (group, match) -> Future<Match.ScheduleView> in
                        let team1Future = try match.team1.get(on: conn)
                        let team2Future = try match.team2.get(on: conn)
                        
                        return map(to: Match.ScheduleView.self, team1Future, team2Future, { team1, team2 in
                            return Match.ScheduleView(id: match.id, openLigaId: match.openLigaId, lastUpdate: match.lastUpdate, group: group, team1: team1, team2: team2, location: nil, date: match.date, isFinished: match.isFinished, viewerCount: match.viewerCount, finalGoalsTeam1: match.finalGoalsTeam1, finalGoalsTeam2: match.finalGoalsTeam2)
                        })
                    }).flatten(on: conn)
                })
            
            let context = BetsKOContext(title: "Tippschein",
                                        userLoggedIn: userLoggedIn,
                                        user: user,
                                        showCookieMessage: showCookieMessage,
                                        groups: try conn.query(Group.self).filter(\.id > 1).all(),
                                        matches: scheduleViews,
                                        bets: try conn.query(Bet.self).filter(\.matchId > 48).filter(\.userId == user!.id).sort(\.matchId).all(),
                                        successfulSave: successfulSave)
            
            return try req.view().render("bets/bets_ko", context)
        }
    }
    
    func betsKOPhasePostHandler(_ req: Request) throws -> Future<Response> {
        let user = try req.authenticated(User.self)
        
        return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<Response> in
            let dataDictFuture = try req.content.decode(Dictionary<String, String>.self)
            let matchCountFuture = try Match.query(on: conn).filter(\.groupId > 1).all()
            
            return dataDictFuture.and(matchCountFuture).map { (dataDict, matches) -> [Bet] in
                //Save bets
                return matches.compactMap({ match -> Bet? in
                    guard let betTeam1String = dataDict["team1_\(match.id!)"],
                        let betTeam2String = dataDict["team2_\(match.id!)"] else {
                            return nil
                    }
                    
                    let betTeam1 = Int(betTeam1String)
                    let betTeam2 = Int(betTeam2String)
                    
                    if Date() >= match.date {
                        return nil
                    }
                    
                    return Bet(matchId: match.id!, userId: user!.id!, betTeam1: betTeam1, betTeam2: betTeam2)
                })
                }.flatMap { bets -> Future<[Bet]> in
                    return try bets.map({ bet -> Future<Bet> in
                        return try conn.query(Bet.self).filter(\.matchId == bet.matchId).filter(\.userId == bet.userId).first().then({ dbBet in
                            if let dbBet = dbBet {
                                dbBet.betTeam1 = bet.betTeam1
                                dbBet.betTeam2 = bet.betTeam2
                                return dbBet.save(on: req)
                            } else {
                                return Bet(matchId: bet.matchId, userId: bet.userId, betTeam1: bet.betTeam1, betTeam2: bet.betTeam2).save(on: conn)
                            }
                        })
                    }).flatten(on: req)
                }.transform(to: req.redirect(to: "/bets/ko?success=true"))
        })
    }
    
    //MARK: Page context structs
    
    struct BetsGroupContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        var group: Group
        var matches: [Match.ScheduleView]
        var teams: [Team]
        var bets: [Bet]
        var champBet: Team.ID?
        var groupTables: [[Group.GroupTableEntryView]]
        let groupLetters = Group.groupLetters
        var successfulSave: Bool
        var currentDate: Date
        var firstMatchDate: Date
    }
    
    struct BetsKOContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        var groups: Future<[Group]>
        var matches: Future<[Match.ScheduleView]>
        var bets: Future<[Bet]>
        
        let currentDate = Date()
        
        var successfulSave: Bool
    }
}
