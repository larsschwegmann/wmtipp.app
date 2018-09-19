//
//  MailgunService.swift
//  App
//
//  Created by Lars Schwegmann on 14.06.18.
//

import Vapor

enum MailgunService {
    case sendMail
}


extension MailgunService {
    
    static var apiKey: String = ""
    
    var domain: String {
        return "mg.wmtipp.app"
    }
    
    var baseURL: URL {
        return URL(string: "https://api:\(MailgunService.apiKey)@api.mailgun.net/v3/\(domain)/")!
    }
    
    var path: String {
        switch self {
        case .sendMail:
            return "messages"
        }
    }
    
}

extension MailgunService {
    
    
    
}
