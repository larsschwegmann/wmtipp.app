//
//  IntConvert.swift
//  App
//
//  Created by Lars Schwegmann on 02.06.18.
//

import Vapor
import Leaf


public final class IntConvert: TagRenderer {
    public init() {}
    
    /// See `TagRenderer`.
    public func render(tag: TagContext) throws -> Future<TemplateData> {
        try tag.requireParameterCount(1)
        
        guard let double = tag.parameters[0].double else {
            throw tag.error(reason: "Specified value is not a double")
        }
        let intValue = Int(double)
        return Future.map(on: tag) { .int(intValue) }
    }
}

