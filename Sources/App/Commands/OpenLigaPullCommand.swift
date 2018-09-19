//
//  OpenLigaPullCommand.swift
//  App
//
//  Created by Lars Schwegmann on 11.06.18.
//

import Vapor
import Fluent

struct OpenLigaPullCommand: Command {
    var arguments: [CommandArgument] {
        return []
    }
    
    var options: [CommandOption] {
        return []
    }
    
    var help: [String] {
        return ["Fetches currently running matches from open liga and syncs results"]
    }
    
    func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        return context.container.withPooledConnection (to: .psql) { conn -> EventLoopFuture<Void> in
            return try Match.updateRunningMatchesFromOpenLigaDB(on: conn, client: context.container.client())
        }
    }
    
    
}
