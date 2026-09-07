import Foundation

public struct ContainerConfig: Codable {
    public let name: String
    public let image: String
    public let workingDir: String
    public let environment: [String: String]
    public let ports: [String: String]
    public let volumes: [String: String]
    
    public init(
        name: String,
        image: String = "ubuntu:22.04",
        workingDir: String = "/workspace",
        environment: [String: String] = [:],
        ports: [String: String] = [:],
        volumes: [String: String] = [:]
    ) {
        self.name = name
        self.image = image
        self.workingDir = workingDir
        self.environment = environment
        self.ports = ports
        self.volumes = volumes
    }
}

public struct ContainerStatus: Codable {
    public let id: String
    public let name: String
    public let state: String
    public let status: String
    
    public init(id: String, name: String, state: String, status: String) {
        self.id = id
        self.name = name
        self.state = state
        self.status = status
    }
}
