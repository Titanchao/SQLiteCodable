
struct sql_class_rw_t {
    var flags: Int32
    var version: Int32
    var ro: UInt
    
    func class_ro_t() -> UnsafePointer<sql_class_ro_t>? {
        return UnsafePointer<sql_class_ro_t>(bitPattern: self.ro)
    }
}

struct sql_class_ro_t {
    var flags: Int32
    var instanceStart: Int32
    var instanceSize: Int32
}

protocol MetadataType : SQLPointerType {
    static var kind: Metadata.Kind? { get }
}

extension MetadataType {
    
    var kind: Metadata.Kind {
        return Metadata.Kind(flag: UnsafePointer<Int>(pointer: pointer).pointee)
    }
    
    init?(anyType: Any.Type) {
        self.init(pointer: unsafeBitCast(anyType, to: UnsafePointer<Int>.self))
        if let kind = type(of: self).kind, kind != self.kind {
            return nil
        }
    }
}

struct Metadata : MetadataType {
    var pointer: UnsafePointer<Int>
    
    init(type: Any.Type) {
        self.init(pointer: unsafeBitCast(type, to: UnsafePointer<Int>.self))
    }
}

struct _Metadata {}

var is64BitPlatform: Bool {
    return MemoryLayout<Int>.size == MemoryLayout<Int64>.size
}

let MetadataKindIsNonHeap = 0x200
let MetadataKindIsRuntimePrivate = 0x100
let MetadataKindIsNonType = 0x400
extension Metadata {
    static let kind: Kind? = nil
    
    enum Kind {
        case `struct`
        case `enum`
        case optional
        case opaque
        case foreignClass
        case tuple
        case function
        case existential
        case metatype
        case objCClassWrapper
        case existentialMetatype
        case heapLocalVariable
        case heapGenericLocalVariable
        case errorObject
        case `class` // The kind only valid for non-class metadata
        init(flag: Int) {
            switch flag {
            case (0 | MetadataKindIsNonHeap): self = .struct
            case (1 | MetadataKindIsNonHeap): self = .enum
            case (2 | MetadataKindIsNonHeap): self = .optional
            case (3 | MetadataKindIsNonHeap): self = .foreignClass
            case (0 | MetadataKindIsRuntimePrivate | MetadataKindIsNonHeap): self = .opaque
            case (1 | MetadataKindIsRuntimePrivate | MetadataKindIsNonHeap): self = .tuple
            case (2 | MetadataKindIsRuntimePrivate | MetadataKindIsNonHeap): self = .function
            case (3 | MetadataKindIsRuntimePrivate | MetadataKindIsNonHeap): self = .existential
            case (4 | MetadataKindIsRuntimePrivate | MetadataKindIsNonHeap): self = .metatype
            case (5 | MetadataKindIsRuntimePrivate | MetadataKindIsNonHeap): self = .objCClassWrapper
            case (6 | MetadataKindIsRuntimePrivate | MetadataKindIsNonHeap): self = .existentialMetatype
            case (0 | MetadataKindIsNonType): self = .heapLocalVariable
            case (0 | MetadataKindIsNonType | MetadataKindIsRuntimePrivate): self = .heapGenericLocalVariable
            case (1 | MetadataKindIsNonType | MetadataKindIsRuntimePrivate): self = .errorObject
            default: self = .class
            }
        }
    }
}

extension Metadata {
    struct Class : ContextDescriptorType {
        
        static let kind: Kind? = .class
        var pointer: UnsafePointer<_Metadata._Class>
        
        var isSwiftClass: Bool {
            get {
                let lowbit = self.pointer.pointee.rodataPointer & 3
                return lowbit != 0
            }
        }
        
        var contextDescriptorOffsetLocation: Int {
            return is64BitPlatform ? 8 : 11
        }
        
        var superclass: Class? {
            guard let superclass = pointer.pointee.superclass else {
                return nil
            }
            
            if !(superclass is SQLiteCodable.Type) {
                return nil
            }
            
            guard let metaclass = Metadata.Class(anyType: superclass) else {
                return nil
            }
            
            return metaclass
        }
        
        var vTableSize: Int {
            return Int(pointer.pointee.classObjectSize - pointer.pointee.classObjectAddressPoint) - (contextDescriptorOffsetLocation + 2) * MemoryLayout<Int>.size
        }
        
        var genericArgumentVector: UnsafeRawPointer? {
            let pointer = UnsafePointer<Int>(pointer: self.pointer)
            var superVTableSize = 0
            if let _superclass = self.superclass {
                superVTableSize = _superclass.vTableSize / MemoryLayout<Int>.size
            }
            let base = pointer.advanced(by: contextDescriptorOffsetLocation + 2 + superVTableSize)
            if base.pointee == 0 {
                return nil
            }
            return UnsafeRawPointer(base)
        }
        
        func _propertyDescriptionsAndStartPoint() -> ([SQLiteAttribute], Int32?)? {
            let instanceStart = pointer.pointee.class_rw_t()?.pointee.class_ro_t()?.pointee.instanceStart
            var result: [SQLiteAttribute] = []
            if let fieldOffsets = self.fieldOffsets {
                class NameAndType {
                    var name: String?
                    var type: Any.Type?
                }
                for i in 0..<self.numberOfFields {
                    if let name = self.reflectionFieldDescriptor?.fieldRecords[i].fieldName,
                        let cMangledTypeName = self.reflectionFieldDescriptor?.fieldRecords[i].mangledTypeName,
                    let fieldType = _getTypeByMangledNameInContext(cMangledTypeName, getMangledTypeNameSize(cMangledTypeName), genericContext: self.contextDescriptorPointer, genericArguments: self.genericArgumentVector) {
                        result.append(SQLiteAttribute(name: name, type: fieldType, offset: fieldOffsets[i]))
                    }
                }
            }
            
            if let superclass = superclass,
                String(describing: unsafeBitCast(superclass.pointer, to: Any.Type.self)) != "SwiftObject",  // ignore the root swift object
                let superclassProperties = superclass._propertyDescriptionsAndStartPoint(),
                superclassProperties.0.count > 0 {
                
                return (superclassProperties.0 + result, superclassProperties.1)
            }
            return (result, instanceStart)
        }
        
        func propertyDescriptions() -> [SQLiteAttribute]? {
            let propsAndStp = _propertyDescriptionsAndStartPoint()
            if let firstInstanceStart = propsAndStp?.1,
                let firstProperty = propsAndStp?.0.first?.offset {
                return propsAndStp?.0.map({ (attr) -> SQLiteAttribute in
                    let offset = attr.offset - firstProperty + Int(firstInstanceStart)
                    return SQLiteAttribute(name: attr.name, type: attr.type, offset: offset)
                })
            } else {
                return propsAndStp?.0
            }
        }
    }
}

extension _Metadata {
    struct _Class {
        var kind: Int
        var superclass: Any.Type?
        var reserveword1: Int
        var reserveword2: Int
        var rodataPointer: UInt
        var classFlags: UInt32
        var instanceAddressPoint: UInt32
        var instanceSize: UInt32
        var instanceAlignmentMask: UInt16
        var runtimeReservedField: UInt16
        var classObjectSize: UInt32
        var classObjectAddressPoint: UInt32
        var nominalTypeDescriptor: Int
        var ivarDestroyer: Int
        // other fields we don't care
        
        func class_rw_t() -> UnsafePointer<sql_class_rw_t>? {
            if MemoryLayout<Int>.size == MemoryLayout<Int64>.size {
                let fast_data_mask: UInt64 = 0x00007ffffffffff8
                let databits_t: UInt64 = UInt64(self.rodataPointer)
                return UnsafePointer<sql_class_rw_t>(bitPattern: UInt(databits_t & fast_data_mask))
            } else {
                return UnsafePointer<sql_class_rw_t>(bitPattern: self.rodataPointer & 0xfffffffc)
            }
        }
    }
}

extension Metadata {
    struct Struct : ContextDescriptorType {
        static let kind: Kind? = .struct
        var pointer: UnsafePointer<_Metadata._Struct>
        var contextDescriptorOffsetLocation: Int {
            return 1
        }
        
        var genericArgumentOffsetLocation: Int {
            return 2
        }
        
        var genericArgumentVector: UnsafeRawPointer? {
            let pointer = UnsafePointer<Int>(pointer: self.pointer)
            let base = pointer.advanced(by: genericArgumentOffsetLocation)
            if base.pointee == 0 {
                return nil
            }
            return UnsafeRawPointer(base)
        }
        
        func propertyDescriptions() -> [SQLiteAttribute]? {
            guard let fieldOffsets = self.fieldOffsets else {
                return []
            }
            var result: [SQLiteAttribute] = []
            class NameAndType {
                var name: String?
                var type: Any.Type?
            }
            for i in 0..<self.numberOfFields {
                if let name = self.reflectionFieldDescriptor?.fieldRecords[i].fieldName,
                    let cMangledTypeName = self.reflectionFieldDescriptor?.fieldRecords[i].mangledTypeName,
                    let fieldType = _getTypeByMangledNameInContext(cMangledTypeName, getMangledTypeNameSize(cMangledTypeName), genericContext: self.contextDescriptorPointer, genericArguments: self.genericArgumentVector) {
                    result.append(SQLiteAttribute(name: name, type: fieldType, offset: fieldOffsets[i]))
                }
            }
            return result
        }
    }
}

extension _Metadata {
    struct _Struct {
        var kind: Int
        var contextDescriptorOffset: Int
        var parent: Metadata?
    }
}

extension Metadata {
    struct ObjcClassWrapper: ContextDescriptorType {
        static let kind: Kind? = .objCClassWrapper
        var pointer: UnsafePointer<_Metadata._ObjcClassWrapper>
        var contextDescriptorOffsetLocation: Int {
            return is64BitPlatform ? 8 : 11
        }
        var targetType: Any.Type? {
            get {
                return pointer.pointee.targetType
            }
        }
    }
}

extension _Metadata {
    struct _ObjcClassWrapper {
        var kind: Int
        var targetType: Any.Type?
    }
}

@_silgen_name("swift_getTypeByMangledNameInContext")
public func _getTypeByMangledNameInContext(
    _ name: UnsafePointer<UInt8>,
    _ nameLength: Int,
    genericContext: UnsafeRawPointer?,
    genericArguments: UnsafeRawPointer?)
    -> Any.Type?

func getMangledTypeNameSize(_ mangledName: UnsafePointer<UInt8>) -> Int {
    return 256
}
