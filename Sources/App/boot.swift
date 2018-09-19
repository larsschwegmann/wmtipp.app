import Vapor
import FluentPostgreSQL
//import Moya

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    // TODO: Replace this once the vapor bug is fixed
    let conn = try app.newConnection(to: .psql).wait()
    
    defer {
        conn.close()
    }
    
    let rowCount = try conn.query("SELECT COUNT(*) AS count FROM locations", []).wait()[0].firstValue(forColumn: "count")?.decode(Int.self)
    guard let count = rowCount, count == 0 else {
        return
    }
    
    try populateLocations(app)
    //try populateOpenLigaData(app)
    try populateTeams(app)
    try populateGroups(app)
    try populateMatchData(app)
}

func populateLocations(_ app: Application) throws {
    //TODO: Double check these ids
    let conn = try app.newConnection(to: .psql).wait()
    
    defer {
        conn.close()
    }
    
    try Location.locations2018.forEach { loc in
        let _ = try loc.create(on: conn).wait()
    }
}

func populateTeams(_ app: Application) throws {
    //TODO: Double check these ids
    let conn = try app.newConnection(to: .psql).wait()
    
    defer {
        conn.close()
    }
    
    try Team.teams2018.forEach { team in
        let _ = try team.create(on: conn).wait()
    }
}

func populateGroups(_ app: Application) throws {
    let conn = try app.newConnection(to: .psql).wait()
    
    defer {
        conn.close()
    }
    
    //let provider = MoyaProvider<OpenLigaService>()
    //let promise = app.eventLoop.newPromise(Moya.Response.self)
    
    let client = try app.client()
    let endpoint = OpenLigaService.getAvailableGroups(league: "fifa18", season: "2018")
    
//    provider.request(.getAvailableGroups(league: "fifa18", season: "2018"), callbackQueue: DispatchQueue.global(), progress: nil) { (result) in
//        switch result {
//        case let .success(res):
//            promise.succeed(result: res)
//        case let .failure(err):
//            promise.fail(error: err)
//        }
//    }
    
    let result = try client.get(endpoint.baseURL.appendingPathComponent(endpoint.path)).wait()
    
    guard let groups = try? result.content.decode([OpenLigaGroup].self).wait() else {
        return
    }
    
    try groups.map { (group) -> Group in
        return Group(openLigaId: group.GroupID, name: group.GroupName, orderId: group.GroupOrderID)
    }.forEach { (group) in
        let _ = try group.create(on: conn).wait()
    }
}

func populateMatchData(_ app: Application) throws {
    let conn = try app.newConnection(to: .psql).wait()
    
    defer {
        conn.close()
    }
    
    //let provider = MoyaProvider<OpenLigaService>()
    //let promise = app.eventLoop.newPromise(Moya.Response.self)

    let client = try app.client()
    let endpoint = OpenLigaService.getMatchData(league: "fifa18", season: "2018")
    
//    provider.request(.getMatchData(league: "fifa18", season: "2018"), callbackQueue: DispatchQueue.global(), progress: nil) { (result) in
//        switch result {
//        case let .success(res):
//            promise.succeed(result: res)
//        case let .failure(err):
//            promise.fail(error: err)
//        }
//    }
    
    let result = try client.get(endpoint.baseURL.appendingPathComponent(endpoint.path)).wait()
    
    //let result = try promise.futureResult.wait()
    
    //let matches = try result.map([OpenLigaMatch].self)
    
    let matches = try result.content.decode([OpenLigaMatch].self).wait()
    
    let dateFormatter = OpenLigaMatch.dateFormatter
    
    try matches.compactMap({ (match) -> Match? in
        guard let team1 = try conn.query(Team.self).filter(\Team.openLigaId == match.Team1.TeamId).first().wait(),
            let team2 = try conn.query(Team.self).filter(\Team.openLigaId == match.Team2.TeamId).first().wait(),
            let group = try conn.query(Group.self).filter(\Group.openLigaId == match.Group.GroupID).first().wait(),
            let location = try conn.query(Location.self).filter(\Location.openLigaId == match.Location.LocationID).first().wait(),
            let date = dateFormatter.date(from: match.MatchDateTime),
            let lastUpdate = dateFormatter.date(from: String(match.LastUpdateDateTime.split(separator: ".")[0])) else {
                print("Error")
                return nil
        }
        
        return Match(openLigaId: match.MatchID, groupId: group.id!, team1Id: team1.id!, team2Id: team2.id!, locationId: location.id!, date: date, isFinished: match.MatchIsFinished, lastUpdate: lastUpdate)
    }).forEach({ (match) in
        let _ = try match.create(on: conn).wait()
    })
}

//func populateOpenLigaData(_ app: Application) throws {
//    let provider = MoyaProvider<OpenLigaService>()
//    let promise = app.eventLoop.newPromise(Moya.Response.self)
//
//    provider.request(.getMatchData(league: "fifa18", season: "2018"), callbackQueue: DispatchQueue.global(), progress: nil) { (result) in
//        switch result {
//        case let .success(res):
//            promise.succeed(result: res)
//        case let .failure(err):
//            promise.fail(error: err)
//        }
//    }
//    let result = try promise.futureResult.wait()
//
//    guard let matches = try? result.map([OpenLigaMatch].self) else {
//        return
//    }
//
//
////    let conn = try app.newConnection(to: .psql).wait()
////    defer {
////        conn.close()
////    }
////    try appTeams.forEach({ (team) in
////        let _ = try team.create(on: conn).wait()
////    })
//
//}
