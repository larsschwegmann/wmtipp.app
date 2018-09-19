//
//  Location.swift
//  App
//
//  Created by Lars Schwegmann on 10.05.18.
//

import Vapor
import FluentPostgreSQL

final class Location: PostgreSQLModel {
    var id: Int?
    var openLigaId: Int
    
    var city: String
    var stadium: String
    
    init(id: Int? = nil, openLigaId: Int, city: String, stadium: String) {
        self.id = id
        self.openLigaId = openLigaId
        self.city = city
        self.stadium = stadium
    }
    
    static let locations2018 = [
        Location(openLigaId: 1120, city: "Jekaterinburg", stadium: "Zentralstadion"),
        Location(openLigaId: 1127, city: "Kaliningrad", stadium: "Kaliningrad-Stadion"),
        Location(openLigaId: 1124, city: "Kasan", stadium: "Kasan-Arena"),
        Location(openLigaId: 1130, city: "Nischni Nowgorod", stadium: "Stadion Nischni Nowgorod"),
        Location(openLigaId: 1125, city: "Moskau", stadium: "Spartak-Stadion"),
        Location(openLigaId: 1133, city: "Samara", stadium: "Kosmos-Arena"),
        Location(openLigaId: 1131, city: "Wolgograd", stadium: "Wolgograd Arena"),
        Location(openLigaId: 1134, city: "St. Petersburg", stadium: "St. Petersburg Stadion"),
        Location(openLigaId: 1123, city: "Sotschi", stadium: "Olympiastadion Sotschi"),
        Location(openLigaId: 1126, city: "Saransk", stadium: "Mordowia Arena"),
        Location(openLigaId: 1129, city: "Rostow am Don", stadium: "Rostow Arena"),
        Location(openLigaId: 1121, city: "Moskau", stadium: "Olympiastadion Luschniki")
    ]
}

extension Location {
    
    var matches: Children<Location, Match> {
        return children(\.locationId)
    }
    
}

extension Location: Migration { }
extension Location: Content { }
extension Location: Parameter { }
