//
//  SQLiteAttribute.swift
//  BrcIot
//
//  Created by tian on 2018/12/11.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit

class SQLiteAttribute {
    public var key = ""
    public var offset: Int = 0
    public var type: Any.Type = Any.Type.self
    public var address: UnsafeMutablePointer<Int8>? = nil
    public var bridged = false
    public var value: Any? = nil
    public var typeName: String {
        return String(describing: type).range(of: "Optional<") == nil ? String(describing: type) : String(describing: type).replacingOccurrences(of: "Optional<", with: "").replacingOccurrences(of: ">", with: "")
    }
    public var isPrimary = false
    public var isUnique = false
    public var isNotNull: Bool {
        return value != nil
    }
    
    public class func getAttributes(forType type: Any.Type) -> [SQLiteAttribute]? {
        if let classDescriptor = Metadata.Class(anyType: type) {
            return classDescriptor.propertyDescriptions()
        }
        return nil
    }
    
    public var columeType: String? {
        return columnKeys[self.typeName]
    }
}


fileprivate let columnKeys = ["String": "TEXT",
                              "NSString": "TEXT",
                              "NSTaggedPointerString": "TEXT",
                              "Int": "INTEGER",
                              "Int8": "INTEGER",
                              "Int16": "INTEGER",
                              "Int32": "INTEGER",
                              "Int64": "INTEGER",
                              "Double": "DOUBLE",
                              "Float": "FLOAT",
                              "CGFloat": "DOUBLE",
                              "Bool": "BOOLEAN",
                              "Date": "DATE"]
