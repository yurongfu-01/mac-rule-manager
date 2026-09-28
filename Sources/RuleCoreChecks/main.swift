import Foundation
import RuleCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw RuleError.invalidPlan("Check failed: " + message) }
}

@main
struct Checks {
    static func main() throws {
        do { _ = try Policy(text: "", version: 1); throw RuleError.invalidPlan("empty policy accepted") }
        catch RuleError.invalidPolicy { }

        let toolResponse = Data("""
        {"choices":[{"message":{"role":"assistant","content":null,"reasoning_content":"thinking","tool_calls":[{"id":"call_1","type":"function","function":{"name":"scan_files","arguments":"{}"}}]}}]}
        """.utf8)
        let parsedTool = try AgentClient.parseResponse(toolResponse)
        try check(parsedTool.toolCalls?.first?.function.name == "scan_files", "tool-call response")
        try check(parsedTool.reasoningContent == "thinking", "reasoning continuation")
        do { _ = try AgentToolProtocol.arguments("{\"shell\":\"open\"}", allowed: [])
             throw RuleError.invalidPlan("unknown tool argument accepted") }
        catch RuleError.invalidPlan { }
        var gate = AgentApprovalGate()
        let approval = gate.prepare()
        try check(!gate.consume(approval), "unapproved plan refused")
        try check(!gate.approve(userText: "先别确认执行"), "ambiguous approval refused")
        try check(gate.approve(userText: "确认执行") && gate.consume(approval), "explicit approval")
        try check(!gate.consume(approval), "approval is single-use")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mac-rule-checks-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("hello.txt")
        try Data("hello".utf8).write(to: source)

        let policy = try Policy(text: "R001: Move text files to Sorted.", version: 1)
        let inventory = try Scanner.scan(root: root)
        try check(inventory.records.count == 1 && !inventory.isPartial, "scan")
        let fileID = inventory.records[0].id

        func json(destination: String, extra: String = "") -> String {
            """
            {"schema_version":1,"policy_hash":"\(policy.hash)","inventory_id":"\(inventory.id)","actions":[{"rule_id":"R001","file_id":"\(fileID)","destination":"\(destination)","reason":"rule","evidence":["text"]\(extra)}],"clarifications":[]}
            """
        }

        do { _ = try PlanValidator.validate(PlanValidator.parse(json(destination: "../escape")), policy: policy, inventory: inventory)
             throw RuleError.invalidPlan("traversal accepted") }
        catch RuleError.invalidPlan { }
        do { _ = try PlanValidator.parse(json(destination: "Sorted", extra: ",\"shell\":\"rm\""))
             throw RuleError.invalidPlan("unknown action field accepted") }
        catch RuleError.invalidPlan { }

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("mac-rule-outside-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let link = root.appendingPathComponent("Linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        do { _ = try PlanValidator.validate(PlanValidator.parse(json(destination: "Linked")), policy: policy, inventory: inventory)
             throw RuleError.invalidPlan("symlink destination accepted") }
        catch RuleError.invalidPlan { }

        let plan = try PlanValidator.parse(json(destination: "Sorted"))
        let action = try PlanValidator.validate(plan, policy: policy, inventory: inventory)[0]
        try check(action.destinationRelativePath == "Sorted/hello.txt", "destination composition")
        var journal: [JournalEntry] = []
        let moved = try Executor.execute(action, inventory: inventory, policy: policy, planID: UUID()) { journal.append($0) }
        try check(moved.status == .verified && journal.count == 2, "move and transaction log")
        try Data("conflict".utf8).write(to: source)
        do { _ = try Executor.undo(moved) { _ in }; throw RuleError.invalidPlan("undo conflict accepted") }
        catch RuleError.conflict { }
        try FileManager.default.removeItem(at: source)
        let undone = try Executor.undo(moved) { journal.append($0) }
        try check(undone.status == .undone && FileManager.default.fileExists(atPath: source.path), "undo")

        let rescanned = try Scanner.scan(root: root)
        let original = rescanned.records[0]
        try Data("changed content".utf8).write(to: source)
        let changedJSON = """
        {"schema_version":1,"policy_hash":"\(policy.hash)","inventory_id":"\(rescanned.id)","actions":[{"rule_id":"R001","file_id":"\(original.id)","destination":"Sorted","reason":"rule","evidence":["text"]}],"clarifications":[]}
        """
        let changedPlan = try PlanValidator.parse(changedJSON)
        let changedAction = try PlanValidator.validate(changedPlan, policy: policy, inventory: rescanned)[0]
        do { _ = try Executor.execute(changedAction, inventory: rescanned, policy: policy, planID: UUID()) { _ in }
             throw RuleError.invalidPlan("changed source accepted") }
        catch RuleError.fileChanged { }

        print("RuleCoreChecks passed: tool calls, approval, policy, scan, JSON, traversal, move, conflict, undo, changed file")
    }
}
