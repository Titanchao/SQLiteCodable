
protocol SQLPointerType : Equatable {
    associatedtype Pointee
    var pointer: UnsafePointer<Pointee> { get set }
}

extension SQLPointerType {
    init<T>(pointer: UnsafePointer<T>) {
        func cast<T, U>(_ value: T) -> U {
            return unsafeBitCast(value, to: U.self)
        }
        self = cast(UnsafePointer<Pointee>(pointer: pointer))
    }
}

extension UnsafePointer {
    init<T>(pointer: UnsafePointer<T>) {
        self = UnsafeRawPointer(pointer).assumingMemoryBound(to: Pointee.self)
    }
}

func relativeObjectPointer<T, U, V>(base: UnsafePointer<T>, offset: U) -> UnsafePointer<V> where U : FixedWidthInteger {
    return UnsafeRawPointer(base).advanced(by: Int(value: offset)).assumingMemoryBound(to: V.self)
}

extension Int {
    fileprivate init<T : FixedWidthInteger>(value: T) {
        switch value {
        case let value as Int: self = value
        case let value as Int32: self = Int(value)
        case let value as Int16: self = Int(value)
        case let value as Int8: self = Int(value)
        default: self = 0
        }
    }
}
