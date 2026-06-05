import Foundation

enum AUStateCodec {
    static func encode(_ fullState: [String: Any]) throws -> String {
        let data = try PropertyListSerialization.data(fromPropertyList: fullState, format: .binary, options: 0)
        return data.base64EncodedString()
    }

    static func decode(_ base64: String) throws -> [String: Any] {
        guard let data = Data(base64Encoded: base64) else {
            throw AudioUnitPresetError.invalidState
        }
        guard let state = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw AudioUnitPresetError.invalidState
        }
        return state
    }
}
