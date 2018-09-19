//
//  ArrayGet.swift
//  App
//
//  Created by Lars Schwegmann on 01.06.18.
//

import Vapor
import Leaf

public final class ArrayGet: TagRenderer {
    public init() {}
    
    /// See `TagRenderer`.
    public func render(tag: TagContext) throws -> Future<TemplateData> {
        try tag.requireParameterCount(2)
    
        guard let array = tag.parameters[0].array else {
            throw tag.error(reason: "Specified value is not an array")
        }
        
        guard let index = tag.parameters[1].int else {
            throw tag.error(reason: "Specified index is not an int")
        }
        
        
        let element = array[index]
        return Future.map(on: tag) { element }
    }
}

