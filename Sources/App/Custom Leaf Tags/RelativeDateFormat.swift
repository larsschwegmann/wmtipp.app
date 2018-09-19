//
//  RelativeDateFormat.swift
//  App
//
//  Created by Lars Schwegmann on 13.06.18.
//

import Vapor
import Leaf

public final class RelativeDateFormat: TagRenderer {
    public init() {}
    
    /// See `TagRenderer`.
    public func render(tag: TagContext) throws -> Future<TemplateData> {
        try tag.requireParameterCount(1)
        
//        guard let param1 = tag.parameters[0].double else {
//            throw tag.error(reason: "Specified value has to be double/time interval")
//        }
//
//        let date1 = Date(timeIntervalSinceReferenceDate: param1)
//        let calendar = Calendar.current
//
//        let comps = calendar.dateComponents([.minute, .hour, .day, .weekOfYear, .month], from: date1, to: Date())
//
//        guard let minutes = comps.minute,
//            let hours = comps.hour,
//            let days = comps.weekOfYear,
//            let months = comps.month else {
//                return Future.map(on: tag) { .string("n/a") }
//        }
//
//        if months >= 1 {
//            return Future.map(on: tag) { .string("vor über \(months == 1 ? "einem Monat" : "vor \(months) Monaten")") }
//        }
//
//        if days >= 1 {
//            return Future.map(on: tag) { .string("vor \(days == 1 ? "einem Tag" : "\(days) Tagen")") }
//        }
//
//        if hours >= 1 {
//            return Future.map(on: tag) { .string("vor \(hours == 1 ? "einer Stunde" : "\(hours) Stunden")") }
//        }
//
//        if minutes >= 1 {
//            return Future.map(on: tag) { .string("vor \(minutes == 1 ? "einer Minute" : "\(minutes) Minuten")") }
//        }
        
        return Future.map(on: tag) { .string("gerade eben") }
    }
}
