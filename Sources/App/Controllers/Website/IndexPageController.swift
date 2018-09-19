//
//  IndexPageController.swift
//  App
//
//  Created by Lars Schwegmann on 08.06.18.
//

import Vapor
import Leaf
import Fluent
import Authentication

struct IndexPageController: RouteCollection {
    
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware())
        router.get(use: indexHandler)
    }
    
    func indexHandler(_ req: Request) throws -> Future<View> {
        let userLoggedIn = try req.isAuthenticated(User.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let user = try req.authenticated(User.self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        let startDate = dateFormatter.date(from: "2018-06-14 17:00")!
        let endDate = dateFormatter.date(from: "2018-07-15 20:30")!
        //let endDate = dateFormatter.date(from: "2018-07-14 20:30")!
        
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: startDate).day
        
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let currentDate = Date()
        
        return req.withPooledConnection(to: .psql, closure: { conn -> EventLoopFuture<View> in
            return Scoreboard.getGlobalScoreboard(on: req).flatMap({ rankings -> Future<View> in
                let context = IndexContext(title: "Startseite",
                                           userLoggedIn: userLoggedIn,
                                           user: user?.convertToPublic(),
                                           showCookieMessage: showCookieMessage,
                                           daysRemaining: daysRemaining,
                                           scoreboard:rankings,
                                           todaysMatches: try Match.todaysMatches(on: conn, user: user),
                                           tomorrowsMatches: try Match.matchesOn(tomorrow, on: conn, user: user),
                                           publicAnnouncements: try News.getPublicAnnouncements(on: conn),
                                           currentDate: currentDate,
                                           endDate: endDate,
                                           userRank: rankings.first(where: { $0.userId == user?.id })?.rank)
                return try req.view().render("index", context)
            })
        })
    }
    
    //MARK: Page context structs
    
    struct IndexContext: PageInfoContext {
        var title: String
        var userLoggedIn: Bool
        var user: User.Public?
        var showCookieMessage: Bool
        
        var daysRemaining: Int?
        
        var scoreboard: [Scoreboard.RankingView]
        var todaysMatches: Future<[Match.IndexView]>
        var tomorrowsMatches: Future<[Match.IndexView]>
        
        var publicAnnouncements: Future<[News.NewsView]>
        var currentDate: Date
        var endDate: Date
        var userRank: Int?
    }
    
}
