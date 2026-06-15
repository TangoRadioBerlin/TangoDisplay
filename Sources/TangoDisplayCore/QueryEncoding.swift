import Foundation

/// Percent-encodes a string for safe use as the *value* of a URL query parameter.
/// Only RFC 3986 unreserved characters pass through unescaped; everything else
/// (including `&`, `?`, `#`, `=`, `+`, space) is encoded, so a value containing
/// such characters can't break out of its parameter or inject extra ones.
public func percentEncodedQueryValue(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
}
