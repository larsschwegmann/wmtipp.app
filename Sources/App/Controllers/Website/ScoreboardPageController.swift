//
//  ScoreboardPageController.swift
//  App
//
//  Created by Lars Schwegmann on 09.06.18.
//

import Vapor
import Leaf
import Fluent
import Authentication

struct ScoreboardPageController: RouteCollection {
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware())
        router.get("scoreboard", use: scoreboardHandler)
    }
    
    func scoreboardHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)?.convertToPublic()
        
        //Compute global scoreboard
        return Scoreboard.getGlobalScoreboard(on: req).flatMap { rankings in
            return try req.view().render("scoreboard", ScoreboardPageContext(title: "Rangliste", userLoggedIn: userLoggedIn, user: user, showCookieMessage: showCookieMessage, scoreboard: rankings))
        }
    }
    
    struct ScoreboardPageContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        var scoreboard: [Scoreboard.RankingView]
    }
}
