import XCTest
@testable import kcalshot

final class RecognitionAggregatorTests: XCTestCase {

    /// 单项结果，grams=100 时 total == caloriesPer100g，便于按总热量断言。
    private func result(_ cal: Double, name: String = "饭", confidence: Double = 0.9) -> RecognitionResult {
        RecognitionResult(
            items: [FoodItem(name: name, grams: 100, caloriesPer100g: cal,
                             proteinPer100g: 0, fatPer100g: 0, carbsPer100g: 0)],
            healthScore: 5, reason: "", recognitionConfidence: confidence,
            portionAssumed: false, assumptions: "", modelUsed: "m"
        )
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(RecognitionAggregator.aggregate([]))
    }

    func testSingleReturnsSame() {
        XCTAssertEqual(RecognitionAggregator.aggregate([result(500)])?.totalCalories, 500)
    }

    func testMedianAcrossSamples() {
        // 总热量 400 / 600 / 1400 → 中位数 600
        let agg = RecognitionAggregator.aggregate([result(400), result(600), result(1400)])
        XCTAssertEqual(agg?.totalCalories, 600)
    }

    func testEvenCountMedian() {
        // 100 / 200 / 300 / 400 → 中位数 250
        let agg = RecognitionAggregator.aggregate([result(100), result(200), result(300), result(400)])
        XCTAssertEqual(agg?.totalCalories, 250)
    }

    func testTightAgreementBoostsConfidence() {
        let agg = RecognitionAggregator.aggregate([
            result(600, confidence: 0.4), result(610, confidence: 0.4), result(590, confidence: 0.4),
        ])
        XCTAssertGreaterThanOrEqual(agg?.recognitionConfidence ?? 0, 0.85)
    }

    func testWideDisagreementForcesReview() {
        let agg = RecognitionAggregator.aggregate([
            result(400, confidence: 0.9), result(800, confidence: 0.9), result(1200, confidence: 0.9),
        ])
        XCTAssertLessThanOrEqual(agg?.recognitionConfidence ?? 1, 0.5)
        XCTAssertEqual(agg?.needsReview, true)
    }

    func testMisalignedNamesSkipPerItemMedian() {
        // 名称不一致时不做逐项中位数，仅选最接近中位数的结果作为基准。
        let agg = RecognitionAggregator.aggregate([
            result(400, name: "饭"), result(600, name: "面"), result(620, name: "粥"),
        ])
        // 中位数 600，最接近的是 600（面）
        XCTAssertEqual(agg?.totalCalories, 600)
    }
}
