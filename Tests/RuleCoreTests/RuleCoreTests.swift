import Foundation
import XCTest
@testable import RuleCore

final class RuleCoreTests: XCTestCase {
    func testToolCallParsingAndApprovalGate() throws {
        let response = Data("""
        {"choices":[{"message":{"role":"assistant","content":null,"reasoning_content":"thinking","tool_calls":[{"id":"call_1","type":"function","function":{"name":"scan_files","arguments":"{}"}}]}}]}
        """.utf8)
        let message = try AgentClient.parseResponse(response)
        XCTAssertEqual(message.toolCalls?.first?.function.name, "scan_files")
        XCTAssertEqual(message.reasoningContent, "thinking")
        XCTAssertThrowsError(try AgentToolProtocol.arguments("{\"shell\":\"open\"}", allowed: []))
        var gate = AgentApprovalGate()
        let id = gate.prepare()
        XCTAssertFalse(gate.consume(id))
        XCTAssertFalse(gate.approve(userText: "先别确认执行"))
        XCTAssertTrue(gate.approve(userText: "确认执行"))
        XCTAssertTrue(gate.consume(id))
        XCTAssertFalse(gate.consume(id))
    }

    func testPolicyRequiresUserRule() throws {
        XCTAssertThrowsError(try Policy(text: "", version: 1))
        XCTAssertThrowsError(try Policy(text: "Just organize things", version: 1))
        let policy = try Policy(text: "R001: Move old logs to Logs.", version: 1)
        XCTAssertEqual(policy.ruleIDs, ["R001"])
        XCTAssertTrue(policy.hash.hasPrefix("sha256:"))
    }

    func testPlanRejectsTraversalAndUnknownActions() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let policy = try Policy(text: "R001: Move text files to Sorted.", version: 1)
        let inventory = try Scanner.scan(root: fixture.root)
        let item = try XCTUnwrap(inventory.records.first)
        let bad = ModelPlan(schemaVersion: 1, policyHash: policy.hash, inventoryID: inventory.id,
                            actions: [ProposedAction(ruleID: "R001", fileID: item.id,
                                                     destination: "../outside",
                                                     reason: "rule", evidence: ["text file"])],
                            clarifications: [])
        XCTAssertThrowsError(try PlanValidator.validate(bad, policy: policy, inventory: inventory))
        XCTAssertThrowsError(try PlanValidator.parse("""
        {"schema_version":1,"policy_hash":"x","inventory_id":"y","actions":[{"rule_id":"R001","file_id":"F1","destination":"Sorted","reason":"x","evidence":["x"],"shell":"rm -rf /"}],"clarifications":[]}
        """))
    }

    func testMoveAndUndoWithConflictProtection() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let policy = try Policy(text: "R001: Move text files to Sorted.", version: 1)
        let inventory = try Scanner.scan(root: fixture.root)
        let item = try XCTUnwrap(inventory.records.first)
        let plan = ModelPlan(schemaVersion: 1, policyHash: policy.hash, inventoryID: inventory.id,
                             actions: [ProposedAction(ruleID: "R001", fileID: item.id,
                                                      destination: "Sorted",
                                                      reason: "rule", evidence: ["text file"])],
                             clarifications: [])
        let action = try XCTUnwrap(PlanValidator.validate(plan, policy: policy, inventory: inventory).first)
        let privateSummary = try XCTUnwrap(AgentDisclosure.moveSummaries([action], includeNames: false).first)
        XCTAssertNil(privateSummary["source"])
        XCTAssertNil(privateSummary["destination"])
        let namedSummary = try XCTUnwrap(AgentDisclosure.moveSummaries([action], includeNames: true).first)
        XCTAssertEqual(namedSummary["source"], "hello.txt")
        var entries: [JournalEntry] = []
        let moved = try Executor.execute(action, inventory: inventory, policy: policy,
                                         planID: UUID()) { entry in entries.append(entry) }
        XCTAssertEqual(moved.status, .verified)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.source.path))
        XCTAssertEqual(entries.count, 2)
        try Data("conflict".utf8).write(to: fixture.source)
        XCTAssertThrowsError(try Executor.undo(moved) { _ in })
        try FileManager.default.removeItem(at: fixture.source)
        let undone = try Executor.undo(moved) { entry in entries.append(entry) }
        XCTAssertEqual(undone.status, .undone)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.source.path))
    }

    func testChangedFileCannotMove() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let policy = try Policy(text: "R001: Move text files to Sorted.", version: 1)
        let inventory = try Scanner.scan(root: fixture.root)
        let item = try XCTUnwrap(inventory.records.first)
        let action = ValidatedAction(proposal: ProposedAction(ruleID: "R001", fileID: item.id,
                                                               destination: "Sorted",
                                                               reason: "rule", evidence: ["text"]),
                                     source: item, destinationRelativePath: "Sorted/hello.txt")
        try Data("changed content".utf8).write(to: fixture.source)
        XCTAssertThrowsError(try Executor.execute(action, inventory: inventory, policy: policy,
                                                   planID: UUID()) { _ in })
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.source.path))
    }
}

private struct Fixture {
    let root: URL
    let source: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        source = root.appendingPathComponent("hello.txt")
        try Data("hello".utf8).write(to: source)
    }

    func clean() { try? FileManager.default.removeItem(at: root) }
}
