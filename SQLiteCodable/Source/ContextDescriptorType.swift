

protocol ContextDescriptorType : MetadataType {
    var contextDescriptorOffsetLocation: Int { get }
}

extension ContextDescriptorType {
    
    var contextDescriptor: ContextDescriptorProtocol? {
        let pointer = UnsafePointer<Int>(pointer: self.pointer)
        let base = pointer.advanced(by: contextDescriptorOffsetLocation)
        if base.pointee == 0 {
            return nil
        }
        if self.kind == .class {
            return ContextDescriptor<_ClassContextDescriptor>(pointer: relativeObjectPointer(base: base, offset: base.pointee - Int(bitPattern: base)))
        } else {
            return ContextDescriptor<_StructContextDescriptor>(pointer: relativeObjectPointer(base: base, offset: base.pointee - Int(bitPattern: base)))
        }
    }
    
    var contextDescriptorPointer: UnsafeRawPointer? {
        let pointer = UnsafePointer<Int>(pointer: self.pointer)
        let base = pointer.advanced(by: contextDescriptorOffsetLocation)
        if base.pointee == 0 {
            return nil
        }
        return UnsafeRawPointer(bitPattern: base.pointee)
    }
    
    var mangledName: String {
        let pointer = UnsafePointer<Int>(pointer: self.pointer)
        let base = pointer.advanced(by: contextDescriptorOffsetLocation)
        let mangledNameAddress = base.pointee + 2 * 4 // 2 properties in front
        if let offset = contextDescriptor?.mangledName,
            let cString = UnsafePointer<UInt8>(bitPattern: mangledNameAddress + offset) {
            return String(cString: cString)
        }
        return ""
    }
    
    var numberOfFields: Int {
        return contextDescriptor?.numberOfFields ?? 0
    }
    
    var fieldOffsets: [Int]? {
        guard let contextDescriptor = self.contextDescriptor else {
            return nil
        }
        let vectorOffset = contextDescriptor.fieldOffsetVector
        guard vectorOffset != 0 else {
            return nil
        }
        if self.kind == .class {
            return (0..<contextDescriptor.numberOfFields).map {
                return UnsafePointer<Int>(pointer: pointer)[vectorOffset + $0]
            }
        } else {
            return (0..<contextDescriptor.numberOfFields).map {
                return Int(UnsafePointer<Int32>(pointer: pointer)[vectorOffset * (is64BitPlatform ? 2 : 1) + $0])
            }
        }
    }
    
    var reflectionFieldDescriptor: FieldDescriptor? {
        guard let contextDescriptor = self.contextDescriptor else {
            return nil
        }
        let pointer = UnsafePointer<Int>(pointer: self.pointer)
        let base = pointer.advanced(by: contextDescriptorOffsetLocation)
        let offset = contextDescriptor.reflectionFieldDescriptor
        let address = base.pointee + 4 * 4 // (4 properties in front) * (sizeof Int32)
        guard let fieldDescriptorPtr = UnsafePointer<_FieldDescriptor>(bitPattern: address + offset) else {
            return nil
        }
        return FieldDescriptor(pointer: fieldDescriptorPtr)
    }
}

protocol ContextDescriptorProtocol {
    var mangledName: Int { get }
    var numberOfFields: Int { get }
    var fieldOffsetVector: Int { get }
    var reflectionFieldDescriptor: Int { get }
}

struct ContextDescriptor<T: _ContextDescriptorProtocol>: ContextDescriptorProtocol, SQLPointerType {
    
    var pointer: UnsafePointer<T>
    
    var mangledName: Int {
        return Int(pointer.pointee.mangledNameOffset)
    }
    
    var numberOfFields: Int {
        return Int(pointer.pointee.numberOfFields)
    }
    
    var fieldOffsetVector: Int {
        return Int(pointer.pointee.fieldOffsetVector)
    }
    
    var fieldTypesAccessor: Int {
        return Int(pointer.pointee.fieldTypesAccessor)
    }
    
    var reflectionFieldDescriptor: Int {
        return Int(pointer.pointee.reflectionFieldDescriptor)
    }
}

protocol _ContextDescriptorProtocol {
    var mangledNameOffset: Int32 { get }
    var numberOfFields: Int32 { get }
    var fieldOffsetVector: Int32 { get }
    var fieldTypesAccessor: Int32 { get }
    var reflectionFieldDescriptor: Int32 { get }
}

struct _StructContextDescriptor: _ContextDescriptorProtocol {
    var flags: Int32
    var parent: Int32
    var mangledNameOffset: Int32
    var fieldTypesAccessor: Int32
    var reflectionFieldDescriptor: Int32
    var numberOfFields: Int32
    var fieldOffsetVector: Int32
}

struct _ClassContextDescriptor: _ContextDescriptorProtocol {
    var flags: Int32
    var parent: Int32
    var mangledNameOffset: Int32
    var fieldTypesAccessor: Int32
    var reflectionFieldDescriptor: Int32
    var superClsRef: Int32
    var metadataNegativeSizeInWords: Int32
    var metadataPositiveSizeInWords: Int32
    var numImmediateMembers: Int32
    var numberOfFields: Int32
    var fieldOffsetVector: Int32
}

