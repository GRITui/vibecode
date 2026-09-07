import Foundation
import OrbStack

public final class SelfHealingTestRunner {
    private let orbStack: OrbStackManager
    private let strategies: [HealingStrategy]
    private let maxHealingAttempts: Int
    
    public init(
        orbStack: OrbStackManager,
        strategies: [HealingStrategy]? = nil,
        maxHealingAttempts: Int = 3
    ) {
        self.orbStack = orbStack
        self.strategies = strategies ?? [
            DependencyInstallStrategy(),
            SyntaxFixStrategy(),
            RetryStrategy()
        ]
        self.maxHealingAttempts = maxHealingAttempts
    }
    
    // MARK: - Run Tests with Self-Healing
    
    public func runTests(
        containerName: String,
        workingDir: String,
        testCommand: String,
        parseResults: @escaping (String) -> [TestResult]
    ) async throws -> TestSuiteResult {
        let context = HealingContext(
            containerName: containerName,
            workingDir: workingDir,
            orbStack: orbStack
        )
        
        var attempt = 0
        var lastResult: TestSuiteResult?
        
        while attempt < maxHealingAttempts {
            attempt += 1
            print("🧪 Test attempt \(attempt)/\(maxHealingAttempts)")
            
            // Run tests
            let startTime = Date()
            let output: String
            do {
                output = try await orbStack.execInContainer(
                    name: containerName,
                    command: ["sh", "-c", "cd \(workingDir) && \(testCommand)"]
                )
            } catch {
                // If command fails, create a failed test result
                let failedResult = TestResult(
                    testName: "Test Suite",
                    passed: false,
                    errorMessage: String(describing: error)
                )
                let suiteResult = TestSuiteResult(
                    results: [failedResult],
                    totalDuration: Date().timeIntervalSince(startTime)
                )
                
                // Try to heal
                if attempt < maxHealingAttempts {
                    let healed = await attemptHealing(
                        testResult: failedResult,
                        context: context
                    )
                    if healed {
                        continue
                    }
                }
                
                return suiteResult
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let testResults = parseResults(output)
            let suiteResult = TestSuiteResult(results: testResults, totalDuration: duration)
            lastResult = suiteResult
            
            // If all tests passed, we're done
            if suiteResult.allPassed {
                print("✅ All tests passed!")
                return suiteResult
            }
            
            print("❌ \(suiteResult.failedCount) test(s) failed")
            
            // Try to heal failed tests
            if attempt < maxHealingAttempts {
                var anyHealed = false
                for result in testResults where !result.passed {
                    let healed = await attemptHealing(testResult: result, context: context)
                    if healed {
                        anyHealed = true
                    }
                }
                
                if !anyHealed {
                    print("⚠️  No healing strategies could fix the failures")
                    break
                }
            }
        }
        
        return lastResult ?? TestSuiteResult(results: [], totalDuration: 0)
    }
    
    // MARK: - Private Helpers
    
    private func attemptHealing(
        testResult: TestResult,
        context: HealingContext
    ) async -> Bool {
        for strategy in strategies {
            if strategy.canHeal(testResult: testResult) {
                print("🔧 Attempting to heal with strategy: \(strategy.name)")
                do {
                    let success = try await strategy.heal(
                        testResult: testResult,
                        context: context
                    )
                    if success {
                        print("✅ Healing successful with \(strategy.name)")
                        return true
                    }
                } catch {
                    print("⚠️  Healing failed with \(strategy.name): \(error)")
                }
            }
        }
        return false
    }
}
