//
//  OpenLigaService.swift
//  App
//
//  Created by Lars Schwegmann on 11.05.18.
//

import Foundation
//import Moya

enum OpenLigaService {
    case getAvailableTeams(league: String, season: String)
    case getAvailableGroups(league: String, season: String)
    case getMatchData(league: String, season: String)
    case getSingleMatchData(matchId: Int)
}


extension OpenLigaService/*: TargetType*/ {
    var baseURL: URL {
        return URL(string: "https://www.openligadb.de/api")!
    }
    
    var path: String {
        switch self {
        case let .getAvailableTeams(league, season):
            return "/getavailableteams/\(league)/\(season)"
        case let .getAvailableGroups(league, season):
            return "/getavailablegroups/\(league)/\(season)"
        case let .getMatchData(league, season):
            return "/getmatchdata/\(league)/\(season)"
        case let .getSingleMatchData(matchId):
            return "/getmatchdata/\(matchId)"
        }
    }
    
//    var method: Moya.Method {
//        return .get
//    }
    
//    var sampleData: Data {
//        return Data(base64Encoded: "")!
//    }
    
//    var task: Task {
//        return .requestPlain
//    }

//    var headers: [String : String]? {
//        return ["Accept": "application/json"]
//    }
}


//Helper struct for conversion
struct OpenLigaTeam: Codable {
    var TeamId: Int
    var ShortName: String
    var TeamGroupName: String?
    var TeamName: String
    var TeamIconUrl: String
}

struct OpenLigaGroup: Codable {
    var GroupID: Int
    var GroupName: String
    var GroupOrderID: Int
}

struct OpenLigaLocation: Codable {
    var LocationID: Int
    var LocationCity: String
    var LocationStadium: String
}

struct OpenLigaMatchResult: Codable {
    var ResultID: Int
    var ResultName: String
    var ResultDescription: String
    var ResultTypeID: Int
    var ResultOrderID: Int
    var PointsTeam1: Int
    var PointsTeam2: Int
}

struct OpenLigaGoal: Codable {
    var GoalID: Int
    var GoalGetterID: Int?
    var GoalGetterName: String?
    var Comment: String?
    var MatchMinute: Int?
    var ScoreTeam1: Int
    var ScoreTeam2: Int
    var IsOvertime: Bool
    var IsPenalty: Bool
    var IsOwnGoal: Bool
}

struct OpenLigaMatch: Codable {
    var MatchID: Int
    var MatchDateTime: String
    var Group: OpenLigaGroup
    var Team1: OpenLigaTeam
    var Team2: OpenLigaTeam
    var Location: OpenLigaLocation
    var LastUpdateDateTime: String
    var NumberOfViewers: Int?
    var MatchIsFinished: Bool
    var MatchResults: [OpenLigaMatchResult]
    var Goals: [OpenLigaGoal]
    
    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return dateFormatter
    }()
}
