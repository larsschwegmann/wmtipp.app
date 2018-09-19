//
//  AdminPageController.swift
//  App
//
//  Created by Lars Schwegmann on 10.06.18.
//

import Vapor
import Leaf
import Fluent
import Authentication

struct AdminPageController: RouteCollection {
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware()).grouped(AdminCheckRedirectMiddleware<User>(path: "/"))
        router.get("admin/dashboard", use: dashboardHandler)
        router.get("admin/mailgun", use: mailgunHandler)
        router.post("admin/mailgun/notifychampbet", use: mailgunPostHandler)
        router.get("admin/results", use: resultsHandler)
        router.post(AdminMatchResultPostData.self, at: "admin/results", Match.parameter, use: resultsPostHandler)
        router.post("admin/results", Match.parameter, "openligadb", use: resultsSingleOpenLigaPostHandler)
        router.post("admin/results/openligadb", use: resultsAllOpenLigaPostHandler)
        
        router.get("admin/groupwinners", use: groupPropagationHandler)
        router.post(AdminGroupPropagationPostData.self, at: "admin/groupwinners", Match.parameter, use: groupPropagationPostHandler)
        router.post("admin/groupwinners", Match.parameter, "openligadb", use: groupPropagationSingleOpenLigaPostHandler)
        
    }
    
    func dashboardHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        
        return try req.view().render("admin/dashboard", AdminDashboardPageContext(title: "Admin", userLoggedIn: userLoggedIn, user: user, showCookieMessage: showCookieMessage))
    }
    
    func mailgunHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        
        return try req.view().render("admin/mailgun", MailgunPageContext(title: "Admin", userLoggedIn: userLoggedIn, user: user, showCookieMessage: showCookieMessage))
    }
    
    func mailgunPostHandler(_ req: Request) throws -> Future<Response> {
        return req.withPooledConnection(to: .psql) { conn -> EventLoopFuture<Response> in
            return conn.query("SELECT * FROM \"users\" WHERE (\"users\".\"champBet\" IS NULL)").flatMap({ results -> Future<Response> in
                return try results.map({ row -> Future<Response> in
                    let email = try row.firstValue(forColumn: "email")!.decode(String.self)
                    let firstName = try row.firstValue(forColumn: "firstName")!.decode(String.self)
                    let content = """
                    Hallo \(firstName)!
                    Du bekommst diese Email, weil du noch keinen Weltmeistertipp abgegeben hast. Dies ist nur bis zum Turnierbeginn (14.06.2018 um 17:00 Uhr) möglich. Lass dir die Chance auf 10 Punkte nicht entgehen!
                    
                    Hier gehts zum Tippschein:
                    https://www.wmtipp.app/bets/groups
                    
                    
                    Viele Grüße
                    
                    Lars
                    """
                    let subject = "Tipp Erinnerung: Weltmeistertipp abgeben"
                    
                    let client = try req.client()
                    let endpoint = MailgunService.sendMail
                    let url = endpoint.baseURL.appendingPathComponent(endpoint.path)
                    
                    return client.post(url, headers: HTTPHeaders(), beforeSend: { req in
                        let dataDict = ["from": "noreply@wmtipp.app",
                                        "to": email,
                                        "subject": subject,
                                        "text": content]
                        try req.content.encode(dataDict, as: .urlEncodedForm)
                    })
                }).flatten(on: req).map({ responses -> Response in
                    try req.session()["success"] = "true"
                    return req.redirect(to: "/admin/mailgun")
                })
            })
        }
    }
    
    func resultsHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        let successfulSave = try req.session()["success"] != nil
        try req.session()["success"] = nil
        
        return req.withPooledConnection(to: .psql) { conn -> EventLoopFuture<View> in
            return try conn.query(Match.self).sort(\.id).all().flatMap { matches -> EventLoopFuture<View> in
                return try matches.map({ match -> Future<Match.ScheduleView> in
                    let locationFuture = try conn.query(Location.self).filter(\.id == match.locationId).first()
                    let team1Future = try conn.query(Team.self).filter(\.id == match.team1Id).first()
                    let team2Future = try conn.query(Team.self).filter(\.id == match.team2Id).first()
                    
                    return map(to: Match.ScheduleView.self, locationFuture, team1Future, team2Future, { location, team1, team2 in
                        return Match.ScheduleView(id: match.id, openLigaId: match.openLigaId, lastUpdate: match.lastUpdate, group: nil, team1: team1!, team2: team2!, location: location!, date: match.date, isFinished: match.isFinished, viewerCount: match.viewerCount, finalGoalsTeam1: match.finalGoalsTeam1, finalGoalsTeam2: match.finalGoalsTeam2)
                    })
                }).flatten(on: req).flatMap(to: View.self, { scheduleViews in
                    return try req.view().render("admin/results", AdminMatchResultsPageContext(title: "Admin | Ergebnisse eintragn", userLoggedIn: userLoggedIn, user: user, showCookieMessage: showCookieMessage, matches: scheduleViews, successfulSave: successfulSave))
                })
            }
        }
    }
    
    func resultsPostHandler(_ req: Request, data: AdminMatchResultPostData) throws -> Future<Response> {
        return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<Response> in
            return try req.parameters.next(Match.self).flatMap(to: Response.self) { match in
                match.isFinished = data.isFinished != nil
                match.finalGoalsTeam1 = data.goalsTeam1 != nil ? Int(data.goalsTeam1!) : nil
                match.finalGoalsTeam2 = data.goalsTeam2 != nil ? Int(data.goalsTeam2!) : nil
                
                return map(to: Response.self, match.update(on: req), try Bet.scoreBets(match: match, conn: conn), {(_, _) in
                    try req.session()["success"] = "true"
                    return req.redirect(to: "/admin/results")
                })
            }
        })
    }
    
    func resultsSingleOpenLigaPostHandler(_ req: Request) throws -> Future<Response> {
        return req.withPooledConnection(to: .psql) { conn -> EventLoopFuture<Response> in
            return try req.parameters.next(Match.self).flatMap(to: Response.self) { match in
                let client = try req.client()
                let endpoint = OpenLigaService.getSingleMatchData(matchId: match.openLigaId)
                
                let result = client.get(endpoint.baseURL.appendingPathComponent(endpoint.path))
                
                return result.flatMap({ result in
                    return try result.content.decode(OpenLigaMatch.self)
                }).flatMap({ openLigaMatch in
                    return map(to: Response.self, try match.updateFromOpenLigaDB(openLigaMatch, conn: conn), try Bet.scoreBets(match: match, conn: conn), {(_, _) in
                        try req.session()["success"] = "openliga"
                        return req.redirect(to: "/admin/results")
                    })
                })
            }
        }
        
    }
    
    func resultsAllOpenLigaPostHandler(_ req: Request) throws -> Future<Response> {
        return req.withPooledConnection(to: .psql) { conn -> EventLoopFuture<Response> in
            return try Match.updateRunningMatchesFromOpenLigaDB(on: conn, client: req.client()).map({ _ in
                try req.session()["success"] = "openliga_all"
                return req.redirect(to: "/admin/results")
            })
        }
        
    }
    
    func groupPropagationHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        
        return req.withPooledConnection(to: .psql) { conn -> EventLoopFuture<View> in
            return try conn.query(Match.self).filter(\.groupId > 1).sort(\.id).all().flatMap { matches -> EventLoopFuture<View> in
                return try matches.map({ match -> Future<Match.ScheduleView> in
                    let locationFuture = try conn.query(Location.self).filter(\.id == match.locationId).first()
                    let team1Future = try conn.query(Team.self).filter(\.id == match.team1Id).first()
                    let team2Future = try conn.query(Team.self).filter(\.id == match.team2Id).first()
                    
                    return map(to: Match.ScheduleView.self, locationFuture, team1Future, team2Future, { location, team1, team2 in
                        return Match.ScheduleView(id: match.id, openLigaId: match.openLigaId, lastUpdate: match.lastUpdate, group: nil, team1: team1!, team2: team2!, location: location!, date: match.date, isFinished: match.isFinished, viewerCount: match.viewerCount, finalGoalsTeam1: match.finalGoalsTeam1, finalGoalsTeam2: match.finalGoalsTeam2)
                    })
                }).flatten(on: req).flatMap(to: View.self, { scheduleViews in
                    return try req.view().render("admin/group_propagation", AdminGroupPropagationPageContext(title: "Admin | Gruppensieger", userLoggedIn: userLoggedIn, user: user, showCookieMessage: showCookieMessage, matches: scheduleViews))
                })
            }
        }
    }
    
    func groupPropagationPostHandler(_ req: Request, data: AdminGroupPropagationPostData) throws -> Future<Response> {
        return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<Response> in
            return try req.parameters.next(Match.self).flatMap(to: Response.self) { match in
                match.team1Id = data.team1Id
                match.team2Id = data.team2Id
                
                return match.update(on: conn).map({ match in
                    return req.redirect(to: "/admin/groupwinners")
                })
            }
        })
    }
    
    func groupPropagationSingleOpenLigaPostHandler(_ req: Request) throws -> Future<Response> {
        return req.withPooledConnection(to: .psql) { conn -> EventLoopFuture<Response> in
            return try req.parameters.next(Match.self).flatMap(to: Response.self) { match in
                let client = try req.client()
                let endpoint = OpenLigaService.getSingleMatchData(matchId: match.openLigaId)
                
                let result = client.get(endpoint.baseURL.appendingPathComponent(endpoint.path))
                
                return result.flatMap({ result in
                    return try result.content.decode(OpenLigaMatch.self)
                }).flatMap({ openLigaMatch in
                    let team1Future = try conn.query(Team.self).filter(\.openLigaId == openLigaMatch.Team1.TeamId).first()
                    let team2Future = try conn.query(Team.self).filter(\.openLigaId == openLigaMatch.Team2.TeamId).first()
                    
                    return flatMap(to: Response.self, team1Future, team2Future, { (team1, team2) -> EventLoopFuture<Response> in
                        guard let team1Id = team1?.id, let team2Id = team2?.id else {
                            throw Abort(.badRequest, reason: "No teams found for given openliga ids")
                        }
                        
                        match.team1Id = team1Id
                        match.team2Id = team2Id
                        
                        return match.update(on: conn).map({ _ -> Response in
                            return req.redirect(to: "/admin/groupwinners")
                        })
                    })
                })
            }
        }
    }
    
    //MARK: - Page context structs
    
    struct AdminDashboardPageContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
    }
    
    struct MailgunPageContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
    }
    
    struct AdminMatchResultsPageContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        let matches: [Match.ScheduleView]
        let successfulSave: Bool?
    }
    
    struct AdminGroupPropagationPageContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        
        let matches: [Match.ScheduleView]
    }
    
    //MARK: - Page POST data
    
    struct AdminMatchResultPostData: Content {
        let isFinished: String?
        //Fugly as hell, but we have to support nil values. When changing this to Int?, nil values crash the server
        let goalsTeam1: String?
        let goalsTeam2: String?
    }
    
    struct AdminGroupPropagationPostData: Content {
        let team1Id: Team.ID
        let team2Id: Team.ID
    }
}
