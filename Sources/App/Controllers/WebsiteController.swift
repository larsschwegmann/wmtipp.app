//
//  WebsiteController.swift
//  App
//
//  Created by Lars Schwegmann on 25.05.18.
//

import Vapor
import Leaf
import Fluent
import Authentication

struct WebsiteController: RouteCollection {
    func boot(router: Router) throws {
        try router.register(collection: IndexPageController())
        try router.register(collection: LoginPageController())
        try router.register(collection: RegisterPageController())
        try router.register(collection: MatchSchedulePageController())
        try router.register(collection: MatchPageController())
        try router.register(collection: BetsPageController())
        try router.register(collection: ScoreboardPageController())
        try router.register(collection: MiscPageController())
        try router.register(collection: UserProfileController())
        try router.register(collection: AdminPageController())
    }
}

//MARK: Leaf Contexts

protocol PageInfoContext: Encodable {
    var title: String { get }
    var userLoggedIn: Bool { get }
    var user: User.Public? { get }
    var showCookieMessage: Bool { get }
}
