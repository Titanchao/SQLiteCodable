//
//  SQLiteAttribute.swift
//  Codable
//
//  Created by tian on 2019/4/9.
//  Copyright © 2019 tian. All rights reserved.
//

import UIKit
import GRDB

struct SQLiteAttribute {
    let name: String
    let type: Any.Type
    let offset: Int
}

class SQLiteColumn {
    public var key = ""
    public var value: Any? = nil
    public var ctype: Database.ColumnType? = nil
    public var isPrimary: Bool = false
    public var isUnique = false
    
    func create(_ t: TableDefinition) {
        let def = t.column(key, ctype)
        if isPrimary { def.primaryKey() }
        if isUnique { def.unique() }
        
        if value != nil, let dv = DatabaseValue(value: value!) {
            def.notNull()
            def.defaults(to: dv)
        }
    }
}

private class SQLiteColumnCache {
    static let share = SQLiteColumnCache()
    var pool: [String: [SQLiteColumn]] = [:]
}

extension SQLiteCodable {
    static func getSQLiteColumns() -> [SQLiteColumn] {
        if let retValue = SQLiteColumnCache.share.pool[databaseTableName] {
            return retValue
        }
        
        var mutableObject = Self.init()
        let mapper = SQLiteMapper()
        var kv = [String: Any]()
        for (k,v) in Mirror(reflecting: mutableObject).children {
            kv[k!] = v
        }
        mutableObject.declareKeys(mapper: mapper)
        guard let attrs = getProperties(forType: type(of: mutableObject)) else {
            return []
        }
        let head = mutableObject.headPointer()
        let columns = attrs.map { (attr) -> SQLiteColumn in
            let col = SQLiteColumn()
            col.key = attr.name
            if mapper.isPrimary(key: head.advanced(by: attr.offset).hashValue) {
                col.isPrimary = true
            } else if mapper.isUnique(key: head.advanced(by: attr.offset).hashValue) {
                col.isUnique = true
            }
            var typeName = String(describing: attr.type)
            if typeName.range(of: "Optional<") == nil {
                if let defaultValue = kv[attr.name] {
                    col.value = defaultValue
                }
            } else {
                typeName = typeName.replacingOccurrences(of: "Optional<", with: "").replacingOccurrences(of: ">", with: "")
            }
            
            if let ctype = columnKeys[typeName] {
                col.ctype = ctype
            }
            return col
        }
        SQLiteColumnCache.share.pool[databaseTableName] = columns
        return columns
    }
}

fileprivate func getProperties(forType type: Any.Type) -> [SQLiteAttribute]? {
    if let structDescriptor = Metadata.Struct(anyType: type) {
        return structDescriptor.propertyDescriptions()
    } else if let classDescriptor = Metadata.Class(anyType: type) {
        return classDescriptor.propertyDescriptions()
    } else if let objcClassDescriptor = Metadata.ObjcClassWrapper(anyType: type),
        let targetType = objcClassDescriptor.targetType {
        return getProperties(forType: targetType)
    }
    return nil
}

typealias BYTE = Int8

extension SQLiteCodable {
    mutating func headPointerOfStruct() -> UnsafeMutablePointer<BYTE> {
        return withUnsafeMutablePointer(to: &self) {
            return UnsafeMutableRawPointer($0).bindMemory(to: BYTE.self, capacity: MemoryLayout<Self>.stride)
        }
    }
    
    mutating func headPointerOfClass() -> UnsafeMutablePointer<BYTE> {
        let opaquePointer = Unmanaged.passUnretained(self as AnyObject).toOpaque()
        let mutableTypedPointer = opaquePointer.bindMemory(to: BYTE.self, capacity: MemoryLayout<Self>.stride)
        return UnsafeMutablePointer<BYTE>(mutableTypedPointer)
    }
    
    
    mutating func headPointer() -> UnsafeMutablePointer<BYTE> {
        if Self.self is AnyClass {
            return self.headPointerOfClass()
        } else {
            return self.headPointerOfStruct()
        }
    }
}

fileprivate let columnKeys = ["String": Database.ColumnType.text,
                              "NSString": Database.ColumnType.text,
                              "NSTaggedPointerString": Database.ColumnType.text,
                              "Int": Database.ColumnType.integer,
                              "Int8": Database.ColumnType.integer,
                              "Int16": Database.ColumnType.integer,
                              "Int32": Database.ColumnType.integer,
                              "Int64": Database.ColumnType.integer,
                              "Double": Database.ColumnType.double,
                              "Float": Database.ColumnType.double,
                              "CGFloat": Database.ColumnType.double,
                              "Bool": Database.ColumnType.boolean,
                              "Date": Database.ColumnType.date]
