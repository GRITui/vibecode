import Foundation
import OrbStack

/// Test double for `ContainerRuntime`. Records calls and returns canned results
/// instead of shelling out to a real `docker`/OrbStack CLI.
final class MockOrbStack: ContainerRuntime {
    var startedContainers: [String] = []
    var stoppedContainers: [String] = []
    var removedContainers: [(name: String, force: Bool)] = []
    var execCalls: [(name: String, command: [String])] = []

    var statusToReturn: ContainerStatus?
    var execResultToReturn: String = ""
    var errorToThrow: Error?

    func startContainer(name: String) async throws {
        if let errorToThrow { throw errorToThrow }
        startedContainers.append(name)
    }

    func stopContainer(name: String) async throws {
        if let errorToThrow { throw errorToThrow }
        stoppedContainers.append(name)
    }

    func removeContainer(name: String, force: Bool) async throws {
        if let errorToThrow { throw errorToThrow }
        removedContainers.append((name: name, force: force))
    }

    func getContainerStatus(name: String) async throws -> ContainerStatus? {
        if let errorToThrow { throw errorToThrow }
        return statusToReturn
    }

    func execInContainer(name: String, command: [String]) async throws -> String {
        if let errorToThrow { throw errorToThrow }
        execCalls.append((name: name, command: command))
        return execResultToReturn
    }
}

struct MockError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
