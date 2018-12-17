//
//  SQLiteMapper.swift
//  BrcIot
//
//  Created by tian on 2018/12/11.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit

public class SQLiteMapper {
    fileprivate var pirmaryKey: Int? = nil
    fileprivate var uniqueKeys: [Int] = []
    fileprivate var ignoreKeys = [Int]()
    
    fileprivate func setPrimaryKey<T>(property: inout T) {
        let pointer = withUnsafePointer(to: &property, { return $0 })
        self.pirmaryKey = pointer.hashValue
    }
    
    internal func isPirmary(key: Int) -> Bool {
        return self.pirmaryKey == key
    }
    
    
    fileprivate func setUniqueKeys<T>(property: inout T) {
        let pointer = withUnsafePointer(to: &property, { return $0 })
        self.uniqueKeys.append(pointer.hashValue)
    }
    
    internal func isUnique(key: Int) -> Bool {
        return self.uniqueKeys.contains(key)
    }
    
    fileprivate func setIgnoreKeys<T>(property: inout T) {
        let pointer = withUnsafePointer(to: &property, { return $0 })
        self.ignoreKeys.append(pointer.hashValue)
    }
    
    internal func isIgnoreKey(key: Int) -> Bool {
        return self.ignoreKeys.contains(key)
    }
}

infix operator <<- : AssignmentPrecedence

public func <<- <T> (mapper: SQLiteMapper, attribute: inout T) {
    mapper.setPrimaryKey(property: &attribute)
}

infix operator <~~ : AssignmentPrecedence

public func <~~ <T> (mapper: SQLiteMapper, attribute: inout T) {
    mapper.setUniqueKeys(property: &attribute)
}

infix operator *-> : AssignmentPrecedence

public func *-> <T> (mapper: SQLiteMapper, attribute: inout T) {
    mapper.setIgnoreKeys(property: &attribute)
}
