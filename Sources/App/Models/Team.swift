//
//  Team.swift
//  App
//
//  Created by Lars Schwegmann on 10.05.18.
//

import Vapor
import FluentPostgreSQL

final class Team: PostgreSQLModel, Codable {
    var id: Int?
    var openLigaId: Int
    var name: String
    var shortName: String
    var iconURLString: String //TODO: Save this as a URL
    var groupLetter: String //not on openLigaDB
    var flagCode: String
    var elo: Int
        
    init(id: Int? = nil, openLigaId: Int, name: String, shortName: String, iconURLString: String, groupLetter: String, flagCode: String, elo: Int = 0) {
        self.id = id
        self.openLigaId = openLigaId
        self.name = name
        self.shortName = shortName
        self.iconURLString = iconURLString
        self.groupLetter = groupLetter
        self.flagCode = flagCode
        self.elo = elo
    }
    
    static let teams2018 = [
        Team(openLigaId: 1392, name: "Ägypten", shortName: "EGY", iconURLString: "", groupLetter: "A", flagCode: "eg"),
        Team(openLigaId: 764, name: "Argentinien", shortName: "ARG", iconURLString: "", groupLetter: "D", flagCode: "ar"),
        Team(openLigaId: 750, name: "Australien", shortName: "AUS", iconURLString: "", groupLetter: "C", flagCode: "au"),
        Team(openLigaId: 2673, name: "Belgien", shortName: "BEL", iconURLString: "", groupLetter: "G", flagCode: "be"),
        Team(openLigaId: 753, name: "Brasilien", shortName: "BRA", iconURLString: "", groupLetter: "E", flagCode: "br"),
        Team(openLigaId: 2669, name: "Costa Rica", shortName: "CRC", iconURLString: "", groupLetter: "E", flagCode: "cr"),
        Team(openLigaId: 758, name: "Dänemark", shortName: "DNK", iconURLString: "", groupLetter: "C", flagCode: "dk"),
        Team(openLigaId: 139, name: "Deutschland", shortName: "DEU", iconURLString: "", groupLetter: "F", flagCode: "de"),
        Team(openLigaId: 755, name: "England", shortName: "ENG", iconURLString: "", groupLetter: "G", flagCode: "gb-eng"),
        Team(openLigaId: 144, name: "Frankreich", shortName: "FRA", iconURLString: "", groupLetter: "C", flagCode: "fr"),
        Team(openLigaId: 2672, name: "Iran", shortName: "IRN", iconURLString: "", groupLetter: "B", flagCode: "ir"),
        Team(openLigaId: 1394, name: "Island", shortName: "ISL", iconURLString: "", groupLetter: "D", flagCode: "is"),
        Team(openLigaId: 749, name: "Japan", shortName: "JPN", iconURLString: "", groupLetter: "H", flagCode: "jp"),
        Team(openLigaId: 1469, name: "Kolumbien", shortName: "COL", iconURLString: "", groupLetter: "H", flagCode: "co"),
        Team(openLigaId: 146, name: "Kroatien", shortName: "CRO", iconURLString: "", groupLetter: "D", flagCode: "hr"),
        Team(openLigaId: 4629, name: "Marokko", shortName: "MAR", iconURLString: "", groupLetter: "B", flagCode: "ma"),
        Team(openLigaId: 761, name: "Mexiko", shortName: "MEX", iconURLString: "", groupLetter: "F", flagCode: "mx"),
        Team(openLigaId: 847, name: "Nigeria", shortName: "NIG", iconURLString: "", groupLetter: "D", flagCode: "ng"),
        Team(openLigaId: 4631, name: "Panama", shortName: "PAN", iconURLString: "", groupLetter: "G", flagCode: "pa"),
        Team(openLigaId: 3177, name: "Peru", shortName: "PER", iconURLString: "", groupLetter: "C", flagCode: "pe"),
        Team(openLigaId: 1410, name: "Polen", shortName: "POL", iconURLString: "", groupLetter: "H", flagCode: "pl"),
        Team(openLigaId: 149, name: "Portugal", shortName: "PRT", iconURLString: "", groupLetter: "B", flagCode: "pt"),
        Team(openLigaId: 150, name: "Russland", shortName: "RUS", iconURLString: "", groupLetter: "A", flagCode: "ru"),
        Team(openLigaId: 2408, name: "Saudi-Arabien", shortName: "SAU", iconURLString: "", groupLetter: "A", flagCode: "sa"),
        Team(openLigaId: 151, name: "Schweden", shortName: "SWE", iconURLString: "", groupLetter: "F", flagCode: "se"),
        Team(openLigaId: 38, name: "Schweiz", shortName: "SWI", iconURLString: "", groupLetter: "E", flagCode: "ch"),
        Team(openLigaId: 4630, name: "Senegal", shortName: "SEN", iconURLString: "", groupLetter: "H", flagCode: "sn"),
        Team(openLigaId: 1404, name: "Serbien", shortName: "SRB", iconURLString: "", groupLetter: "E", flagCode: "rs"),
        Team(openLigaId: 170, name: "Spanien", shortName: "ESP", iconURLString: "", groupLetter: "B", flagCode: "es"),
        Team(openLigaId: 751, name: "Südkorea", shortName: "KOR", iconURLString: "", groupLetter: "F", flagCode: "kr"),
        Team(openLigaId: 1391, name: "Tunesien", shortName: "TUN", iconURLString: "", groupLetter: "G", flagCode: "tn"),
        Team(openLigaId: 849, name: "Uruguay", shortName: "URY", iconURLString: "", groupLetter: "A", flagCode: "uy"),
        Team(openLigaId: 4633, name: "Platzhalter", shortName: "---", iconURLString: "", groupLetter: "", flagCode: "")
    ]

}

extension Team {
    var homeMatches: Children<Team, Match> {
        return children(\.team1Id)
    }
    
    var awayMatches: Children<Team, Match> {
        return children(\.team2Id)
    }
}

extension Team: Migration { }
extension Team: Content { }
extension Team: Parameter { }

//extension URL: PostgreSQLArrayCustomConvertible {
//    public static var mySQLColumnDefinition: MySQLColumnDefinition {
//        return .varChar(length: 255)
//    }
//}
