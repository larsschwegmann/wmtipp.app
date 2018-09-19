//
//  MiscPageController.swift
//  App
//
//  Created by Lars Schwegmann on 09.06.18.
//

import Vapor
import Leaf
import Authentication

struct MiscPageController: RouteCollection {
    func boot(router: Router) throws {
        let router = router.grouped(User.authSessionsMiddleware())
        router.get("/rules", use: { try $0.view().render("misc/rules") })
        router.get("/dsgvo", use: { try $0.view().render("misc/dsgvo") })
        router.get("/impressum", use: { try $0.view().render("misc/impressum") })
    }
}
