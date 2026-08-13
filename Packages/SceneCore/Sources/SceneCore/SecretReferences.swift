import Foundation

public struct SecretReferenceUsage: Equatable, Identifiable, Sendable {
    public var sceneID: String
    public var sceneName: String
    public var actionID: String
    public var actionName: String
    public var environmentName: String
    public var id: String { "\(sceneID)\u{0}\(actionID)\u{0}\(environmentName)" }

    public init(sceneID: String, sceneName: String, actionID: String, actionName: String, environmentName: String) {
        self.sceneID = sceneID
        self.sceneName = sceneName
        self.actionID = actionID
        self.actionName = actionName
        self.environmentName = environmentName
    }
}

public extension Scene {
    func secretReferenceUsages(id referenceID: String) -> [SecretReferenceUsage] {
        (actions + deactivationActions).flatMap { action in
            action.secretEnvironment.compactMap { name, value in
                guard case .secretReference(let storedID) = value, storedID == referenceID else { return nil }
                return .init(sceneID: self.id, sceneName: self.name, actionID: action.id, actionName: action.displayName, environmentName: name)
            }
        }
    }

    func replacingSecretReference(from oldID: String, to newID: String) -> Scene {
        var copy = self
        copy.actions = actions.map { $0.replacingSecretReference(from: oldID, to: newID) }
        copy.deactivationActions = deactivationActions.map { $0.replacingSecretReference(from: oldID, to: newID) }
        return copy
    }
}

private extension SceneAction {
    var secretEnvironment: [String: EnvironmentValue] {
        switch self {
        case .runProcess(let value): value.environment
        case .managedProcess(let value): value.environment
        default: [:]
        }
    }

    func replacingSecretReference(from oldID: String, to newID: String) -> SceneAction {
        func replaced(_ values: [String: EnvironmentValue]) -> [String: EnvironmentValue] {
            values.mapValues { value in
                guard case .secretReference(let id) = value, id == oldID else { return value }
                return .secretReference(newID)
            }
        }
        switch self {
        case .runProcess(var value): value.environment = replaced(value.environment); return .runProcess(value)
        case .managedProcess(var value): value.environment = replaced(value.environment); return .managedProcess(value)
        default: return self
        }
    }
}
