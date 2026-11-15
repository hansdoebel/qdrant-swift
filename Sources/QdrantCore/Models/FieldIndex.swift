import Foundation

public enum Tokenizer: String, Sendable, Codable {
    case prefix
    case whitespace
    case word
    case multilingual
    case code
}

public enum TextScoring: String, Sendable, Codable {
    case bm25
}

public enum Stemmer: Sendable {
    case snowball(language: String)
    case disabled
}

public struct TextIndexOptions: Sendable {
    public var tokenizer: Tokenizer
    public var scoring: TextScoring?
    public var stemmer: Stemmer?
    public var nested: String?

    public init(
        tokenizer: Tokenizer = .word,
        scoring: TextScoring? = nil,
        stemmer: Stemmer? = nil,
        nested: String? = nil
    ) {
        self.tokenizer = tokenizer
        self.scoring = scoring
        self.stemmer = stemmer
        self.nested = nested
    }
}

public struct FieldIndexSchema: Sendable {
    public var type: FieldType
    public var text: TextIndexOptions?
    public var nested: String?

    public init(type: FieldType, text: TextIndexOptions? = nil, nested: String? = nil) {
        self.type = type
        self.text = text
        self.nested = nested
    }

    public static func text(_ options: TextIndexOptions) -> FieldIndexSchema {
        FieldIndexSchema(type: .text, text: options, nested: options.nested)
    }
}
