import XCTest

class SentimentAnalysisTests: XCTestCase {

    func test_positiveScore() {
        let message = "It is always the simple that produces the marvelous."
        // by Amelia E. Barr

        let sentiment = SentimentAnalysis(of: message, being: .sentence)
        XCAssertGreaterThan(sentiment.detectedScore, 0)
    }

    func test_negativeScore() {
        let message = [
            "You're going to pay a price for every bloody thing you do and everything you don't do."
            "You don't get to choose to not pay a price."
            "You get to choose which poison you're going to take."
            "That's it."
        ].joined(separator: " ")
        // by Jordan B. Peterson

        let sentiment = SentimentAnalysis(of: message, being: .paragraph)
        XCAssertLowerThan(sentiment.detectedScore, 0)
    }
}
