//
//  SetupCommand.swift
//  App
//
//  Created by Lars Schwegmann on 02.06.18.
//

import Vapor
import Authentication

struct SetupCommand: Command {
    var arguments: [CommandArgument] {
        return [.argument(name: "password", help: ["The password for the Admin Account"])]
    }
    
    var options: [CommandOption] {
        return []
    }
    
    var help: [String] {
        return ["Sets up the Database"]
    }
    
    func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        let adminPassword = try context.argument("password")
        return context.container.withPooledConnection(to: .psql) { conn -> EventLoopFuture<Void> in
            let hashedPassword = try BCrypt.hash(adminPassword)
            let user = User(firstName: "Lars", lastName: "Schwegmann", username: "larsschwegmann", email: "schwegmannlars@gmail.com", password: hashedPassword, isAdmin: true)
            return user.create(on: conn).flatMap({ user in
                Bet.createEmptyBets(for: user, on: conn)
            }).transform(to: ())
        }
    }
    
    
}
