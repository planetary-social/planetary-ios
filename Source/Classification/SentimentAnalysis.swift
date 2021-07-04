import NaturalLanguage

/// Detect positive and negative message by tagging text with its sentiment score.

public class SentimentAnalysis {

    ///

    public var message: String { return tagger.string }

    ///

    public let unit: NLTokenUnit

    ///

    private let tagger = NLTagger(tagSchemes: [.sentimentScore])

    ///

    public init(of message: String, being unit: NLTokenUnit) {
        self.tagger.string = message
        self.unit = unit
    }

    /// Get the sentiment score of the message.
    ///
    /// - Note: Supports 7 languages: English, French, Italian, German, Spanish, Portuguese, and Simplified Chinese.
    ///
    /// - Returns: The score as a floating-point number between -1 and 1, if possible to detect; otherwise `nil`.
    ///

    public var detectedScore: Float? {
        let (score, _) = tagger.tag(at: message.startIndex, unit: unit, scheme: .sentimentScore)
        return score?.rawValue
    }

}
