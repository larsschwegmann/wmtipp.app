//
//  DateIsBefore.swift
//  App
//
//  Created by Lars Schwegmann on 07.06.18.
//

import Vapor
import Leaf

public final class DateIsBefore: TagRenderer {
    public init() {}
    
    /// See `TagRenderer`.
    public func render(tag: TagContext) throws -> Future<TemplateData> {
        try tag.requireParameterCount(2)
        
        guard let param1 = tag.parameters[0].double, let param2 = tag.parameters[1].double else {
            throw tag.error(reason: "Specified values have to be doubles/time intervals")
        }
        
        let date1 = Date(timeIntervalSinceReferenceDate: param1)
        let date2 = Date(timeIntervalSinceReferenceDate: param2)
        return Future.map(on: tag) { .bool(date1 < date2) }
    }
}
