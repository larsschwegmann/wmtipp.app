//
//  MatchSchedulePageController.swift
//  App
//
//  Created by Lars Schwegmann on 08.06.18.
//

import Vapor
import Fluent
import Leaf
import Authentication

struct MatchSchedulePageController: RouteCollection {
    
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware())
        router.get("schedule") { req -> Response in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let switchDate = dateFormatter.date(from: "2018-06-29")! //TODO: Remove magic number
            if Date() < switchDate {
                return req.redirect(to: "/schedule/groups")
            } else {
                return req.redirect(to: "/schedule/ko")
            }
        }
        router.get("schedule/groups", use: matchScheduleGroupPhaseHandler)
        router.get("schedule/ko", use: matchScheduleKOPhaseHandler)
    }
    
    func matchScheduleGroupPhaseHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        
        return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<View> in
            return try conn.query(Group.self).filter(\.id == 1).first().flatMap(to: View.self, { group in
                guard let group = group else {
                    throw Abort(.internalServerError, reason: "Couldn't find group with id 1")
                }
                return try group.matches.query(on: conn).sort(\.id).all().flatMap(to: View.self, { matches in
                    return try matches.map({ match -> Future<Match.ScheduleView> in
                        let locationFuture = try match.location.get(on: conn)
                        let team1Future = try match.team1.get(on: conn)
                        let team2Future = try match.team2.get(on: conn)
                        
                        return map(to: Match.ScheduleView.self, locationFuture, team1Future, team2Future) { location, team1, team2 in
                            return Match.ScheduleView(id: match.id, openLigaId: match.openLigaId, lastUpdate: match.lastUpdate, group: group, team1: team1, team2: team2, location: location, date: match.date, isFinished: match.isFinished, viewerCount: match.viewerCount, finalGoalsTeam1: match.finalGoalsTeam1, finalGoalsTeam2: match.finalGoalsTeam2)
                        }
                    }).flatten(on: req).flatMap(to: View.self, { scheduleViews in
                        try Group.groupLetters.map({ groupLetter in
                            return try Group.computeGroupTable(groupLetter, on: conn)
                        }).flatten(on: req).flatMap({ groupTables in
                            let context = MatchScheduleGroupsContext(title: "Spielplan",
                                                                     userLoggedIn: userLoggedIn,
                                                                     user: user,
                                                                     showCookieMessage: showCookieMessage,
                                                                     group: group,
                                                                     matches: scheduleViews,
                                                                     groupTables: groupTables)
                            return try req.view().render("schedule/schedule_groups", context)
                        })
                    })
                })
            })
        })
    }
    
    func matchScheduleKOPhaseHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        
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
            
            let context = MatchScheduleKOContext(title: "Spielplan",
                                          userLoggedIn: userLoggedIn,
                                          user: user,
                                          showCookieMessage: showCookieMessage,
                                          groups: try conn.query(Group.self).filter(\.id > 1).sort(\.id).all(),
                                          matches: scheduleViews)
            
            return try req.view().render("schedule/schedule_ko", context)
        }
    }
    
    //MARK: - Page context structs
    
    struct MatchScheduleGroupsContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        var group: Group
        var matches: [Match.ScheduleView]
        var groupTables: [[Group.GroupTableEntryView]]
        let groupLetters = Group.groupLetters //TODO: Dont hardcode this
    }
    
    struct MatchScheduleKOContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        var groups: Future<[Group]>
        var matches: Future<[Match.ScheduleView]>
        
    }
    
}
