import Foundation

public struct TestResult: Codable {
    public let testName: String
    public let passed: Bool
    public let errorMessage: String?
    public let duration: TimeInterval
    
    public init(testName: String, passed: Bool, errorMessage: String? = nil, duration: TimeInterval = 0) {
        self.testName = testName
        self.passed = passed
        self.errorMessage = errorMessage
        self.duration = duration
    }
}

public struct TestSuiteResult: Codable {
    public let results: [TestResult]
    public let totalDuration: TimeInterval
    public let passedCount: Int
    public let failedCount: Int
    
    public init(results: [TestResult], totalDuration: TimeInterval) {
        self.results = results
        self.totalDuration = totalDuration
        self.passedCount = results.filter { $0.passed }.count
        self.failedCount = results.filter { !$0.passed }.count
    }
    
    public var allPassed: Bool {
        return failedCount == 0
    }
}
