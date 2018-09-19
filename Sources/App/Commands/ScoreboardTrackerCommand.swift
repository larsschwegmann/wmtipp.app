//
//  ScoreboardTrackerCommand.swift
//  App
//
//  Created by Lars Schwegmann on 14.06.18.
//

import Vapor
import Authentication

struct ScoreboardTrackerCommand: Command {
    var arguments: [CommandArgument] {
        return []
    }
    
    var options: [CommandOption] {
        return []
    }
    
    var help: [String] {
        return ["Write current ranks to db"]
    }
    
    func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        let calendar = Calendar.current
        let date = calendar.startOfDay(for: Date())
        
        return context.container.withPooledConnection(to: .psql) { conn -> EventLoopFuture<Void> in
            return try conn.query(Scoreboard.self).filter(\.date == date).count().flatMap({ rowCount -> EventLoopFuture<Void> in
                if rowCount > 0 {
                    return context.container.eventLoop.newSucceededFuture(result: ())
                } else {
                    return Scoreboard.getGlobalScoreboard(on: context.container).flatMap { rankings in
                        return rankings.map({ ranking -> Future<Scoreboard> in
                            
                            let scoreboardEntry = Scoreboard(userId: ranking.userId, date: date, rank: ranking.rank)
                            return scoreboardEntry.save(on: conn)
                        }).flatten(on: context.container)
                    }.transform(to: ())
                }
            })
            
        }
    }
    
}
