//
//  News.swift
//  App
//
//  Created by Lars Schwegmann on 08.06.18.
//

import Vapor
import FluentPostgreSQL

//Custom News Type Enum

//enum NewsType: String, Codable {
//    case plainText = "plainText"
//}

//

final class News: Codable {
    var id: Int?
    var type: String
    var isPublicAnnouncement: Bool
    var communityId: Community.ID? //nil -> public announcements, system wide messages
    var authorId: User.ID? //nil -> System generated message
    var date: Date
    
    var title: String
    var subtitle: String?
    var content: String
    
    
    init(id: Int? = nil, type: String, isPublicAnnouncement: Bool, communityId: Community.ID? = nil, authorId: User.ID? = nil, title: String, subtitle: String? = nil, content: String, date: Date) {
        self.id = id
        self.type = type
        self.isPublicAnnouncement = isPublicAnnouncement
        self.communityId = communityId
        self.authorId = authorId
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.date = date
    }
    
    struct NewsView: Codable {
        var id: Int?
        var type: String
        var isPublicAnnouncement: Bool
        var community: Community? //nil -> public announcements, system wide messages
        var author: User.Public? //nil -> System generated message
        var date: Date
        
        var title: String
        var subtitle: String?
        var content: String
    }
    
}

extension News {
    
    static func getPublicAnnouncements(on conn: PostgreSQLConnection) throws -> Future<[News.NewsView]> {
        //Add .join(Community.self, field: \Community.id, to: \News.communityId, method: .outer).alsoDecode(Community.self) once we add communities
        return try conn.query(News.self).filter(\.isPublicAnnouncement == true).join(User.self, field: \User.id, to: \News.authorId, method: .outer).alsoDecode(User.self).sort(\.date, .descending).all().map({ newsTuples in
            return newsTuples.map({ tuple in
//                let news = tuple.0.0
//                let user = tuple.0.1.convertToPublic()
//                let community = tuple.1
                let news = tuple.0
                let user = tuple.1
                return NewsView(id: news.id, type: news.type, isPublicAnnouncement: news.isPublicAnnouncement, community: nil, author: user.convertToPublic(), date: news.date, title: news.title, subtitle: news.title, content: news.content)
            })
        })
    }
    
}

extension News: PostgreSQLModel { }
extension News: Content { }
extension News: Migration { }
extension News: Parameter { }
