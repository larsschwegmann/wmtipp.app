//
//  Group.swift
//  App
//
//  Created by Lars Schwegmann on 10.05.18.
//

import Vapor
import FluentPostgreSQL

final class Group: PostgreSQLModel {
    var id: Int?
    var openLigaId: Int
    var name: String
    var orderId: Int? //From OpenLigaDB
    
    init(id: Int? = nil, openLigaId: Int, name: String, orderId: Int?) {
        self.id = id
        self.openLigaId = openLigaId
        self.name = name
        self.orderId = orderId
    }
    
    struct GroupTableEntryView: Codable {
        var team: Team
        var goals: Int
        var diff: Int
        var score: Int
    }
}

extension Group {
    
    var matches: Children<Group, Match> {
        return children(\.groupId)
    }
    
}

extension Group {
    
    static func computeGroupTable(_ groupLetter: String, on conn: PostgreSQLConnection) throws -> Future<[Group.GroupTableEntryView]> {
        return try Team.query(on: conn).filter(\.groupLetter == groupLetter).all().flatMap(to: [Group.GroupTableEntryView].self) { teams in
            return try teams.map({ team -> Future<GroupTableEntryView> in
                return try Match.query(on: conn).filter(\.groupId == 1).group(.or, closure: { qb in
                    try qb.filter(\.team1Id == team.id).filter(\.team2Id == team.id)
                }).all().map(to: Group.GroupTableEntryView.self, { matches in
                    return try calculateTableEntries(matches: matches, team: team)
                })
            }).flatten(on: conn).map({ entries in
                return entries.sorted(by: { (g1, g2) -> Bool in
                    if g1.score == g2.score {
                        if g1.diff == g2.diff {
                            return g1.goals > g2.goals
                        } else {
                            return g1.diff > g2.diff
                        }
                    } else {
                        return g1.score > g2.score
                    }
                })
            })
        }
    }
    
    static func calculateTableEntries(matches: [Match], team: Team) throws -> GroupTableEntryView {
        return matches.map({match -> (goals: Int, diff: Int, score: Int) in
            if match.team1Id == team.id {
                //team is team1
                return (goals: match.finalGoalsTeam1 ?? 0, diff: (match.finalGoalsTeam1 ?? 0) - (match.finalGoalsTeam2 ?? 0), score: match.scoreTeam1)
            } else {
                //team is team2
                return (goals: match.finalGoalsTeam2 ?? 0, diff: (match.finalGoalsTeam2 ?? 0) - (match.finalGoalsTeam1 ?? 0), score: match.scoreTeam2)
            }
        }).reduce(GroupTableEntryView(team: team, goals: 0, diff: 0, score: 0), {(acc, next) -> GroupTableEntryView in
            return GroupTableEntryView(team: acc.team, goals: acc.goals + next.goals, diff: acc.diff + next.diff, score: acc.score + next.score)
        })
    }
    
}

extension Group {
    static let groupLetters = ["A", "B", "C", "D", "E", "F", "G", "H"]
}

extension Group: Migration { }
extension Group: Content { }
extension Group: Parameter { }
