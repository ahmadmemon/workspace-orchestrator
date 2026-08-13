import XCTest
@testable import SceneCore

final class RunHistoryFeatureTests: XCTestCase {
    func testLocalCalendarDatePresetsUseDayBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: -4 * 3_600))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12)))
        let todayStart = calendar.startOfDay(for: now)
        let scene = Scene(id: "scene", name: "Calendar Test")
        let dates = [
            calendar.date(byAdding: .second, value: -1, to: todayStart)!,
            todayStart,
            calendar.date(byAdding: .day, value: -6, to: todayStart)!,
            calendar.date(byAdding: .day, value: -7, to: todayStart)!,
            calendar.date(byAdding: .day, value: -29, to: todayStart)!,
            calendar.date(byAdding: .day, value: -30, to: todayStart)!
        ]
        let runs = dates.enumerated().map { index, date -> SceneRunResult in
            var run = SceneRunResult(scene: scene, id: "run-\(index)")
            run.startedAt = date
            return run
        }

        XCTAssertEqual(RunHistoryFiltering.filter(runs, using: .init(datePreset: .today), calendar: calendar, now: now).map(\.id), ["run-1"])
        XCTAssertEqual(Set(RunHistoryFiltering.filter(runs, using: .init(datePreset: .last7Days), calendar: calendar, now: now).map(\.id)), Set(["run-0", "run-1", "run-2"]))
        XCTAssertEqual(Set(RunHistoryFiltering.filter(runs, using: .init(datePreset: .last30Days), calendar: calendar, now: now).map(\.id)), Set(["run-0", "run-1", "run-2", "run-3", "run-4"]))

        let custom = RunHistoryFilter(datePreset: .custom, customStart: dates[3], customEnd: dates[2])
        XCTAssertEqual(Set(RunHistoryFiltering.filter(runs, using: custom, calendar: calendar, now: now).map(\.id)), Set(["run-2", "run-3"]))
    }

    func testFailedRetryIncludesDependentsAndRevalidatesStoredApproval() throws {
        let first = SceneAction.runProcess(.init(id: "first", executable: "/usr/bin/true", approvalFingerprint: "stale"))
        let failed = SceneAction.runProcess(.init(id: "failed", executable: "/usr/bin/false", approvalFingerprint: "stale", configuration: .init(dependencies: ["first"])))
        let dependent = SceneAction.wait(.init(id: "dependent", durationSeconds: 1, configuration: .init(dependencies: ["failed"])))
        let unrelated = SceneAction.wait(.init(id: "unrelated", durationSeconds: 1))
        let scene = Scene(name: "Snapshot", actions: [first, failed, dependent, unrelated])
        var run = SceneRunResult(scene: scene)
        run.actionRecords[0].status = .succeeded
        run.actionRecords[1].status = .failed
        run.actionRecords[2].status = .skipped
        run.actionRecords[3].status = .succeeded

        let plan = try HistoricalRunPlanner.retryPlan(for: run, scope: .failedAndDependents)
        XCTAssertEqual(plan.includedActionIDs, ["failed", "dependent"])
        XCTAssertEqual(plan.assumedSuccessfulDependencyIDs, ["first"])
        XCTAssertEqual(plan.scene.actions[0].configuration.dependencies, [])
        if case .runProcess(let process) = plan.scene.actions[0] { XCTAssertNil(process.approvalFingerprint) }
        else { XCTFail("Expected process action") }
        XCTAssertNoThrow(try SceneValidator.validate(plan.scene))
    }

    func testDiagnosticExportRedactsSecretsAndContainsOnlySelectedRun() {
        let scene = Scene(name: "Selected")
        var run = SceneRunResult(scene: scene, id: "selected-run")
        run.errorMessage = "token=super-secret-value"
        run.actionRecords = [.init(id: "action", name: "Action")]
        run.actionRecords[0].processResult = .init(stdout: "authorization: Bearer abcdefghijkl", stderr: "", exitCode: 1, startedAt: Date(), endedAt: Date(), timedOut: false, cancelled: false)

        let text = RunDiagnosticExport.text(for: run)
        XCTAssertTrue(text.contains("selected-run"))
        XCTAssertFalse(text.contains("super-secret-value"))
        XCTAssertFalse(text.contains("abcdefghijkl"))
        XCTAssertTrue(text.contains("[REDACTED]"))
    }

    func testStoreRetainsBoundedOutputMetadataAndPreservesCorruptFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONRunHistoryStore(directoryURL: directory, retention: .init(maximumRunCount: 10, retentionDays: 30, maximumOutputBytesPerAction: 24))
        let scene = Scene(name: "Output", actions: [.runProcess(.init(id: "process", executable: "/usr/bin/true"))])
        var run = SceneRunResult(scene: scene, id: "bounded")
        run.status = .ready
        run.startedAt = Date()
        run.endedAt = Date()
        run.actionRecords[0].status = .succeeded
        run.actionRecords[0].processResult = .init(stdout: "token=very-secret-value plus output", stderr: "stderr", exitCode: 0, startedAt: Date(), endedAt: Date(), timedOut: false, cancelled: false)
        try await store.save(run)

        let storedRuns = try await store.loadRuns()
        let loaded = try XCTUnwrap(storedRuns.first)
        let result = try XCTUnwrap(loaded.actionRecords[0].processResult)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertLessThanOrEqual(Data((result.stdout + result.stderr).utf8).count, 24)
        XCTAssertFalse(result.stdout.contains("very-secret-value"))
        XCTAssertEqual(loaded.actionRecords[0].outputTruncated, true)

        let corrupt = directory.appendingPathComponent("corrupt.json")
        try Data("not-json".utf8).write(to: corrupt)
        let corruptNames = try await store.corruptFileNames()
        XCTAssertEqual(corruptNames, ["corrupt.json"])
        try await store.clear()
        XCTAssertTrue(FileManager.default.fileExists(atPath: corrupt.path))
        let runsAfterClear = try await store.loadRuns()
        XCTAssertTrue(runsAfterClear.isEmpty)
    }

    func testPruneUsesRunDateAndNeverDeletesActiveOrCorruptRecords() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = JSONRunHistoryStore(directoryURL: directory, retention: .init(maximumRunCount: 1, retentionDays: 7), calendar: calendar)
        let reference = Date(timeIntervalSince1970: 1_786_492_800)
        let scene = Scene(name: "Prune")
        var newest = SceneRunResult(scene: scene, id: "newest"); newest.status = .ready; newest.startedAt = reference
        var older = SceneRunResult(scene: scene, id: "older"); older.status = .failed; older.startedAt = calendar.date(byAdding: .day, value: -1, to: reference)
        var active = SceneRunResult(scene: scene, id: "active"); active.status = .running; active.startedAt = calendar.date(byAdding: .day, value: -100, to: reference)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(newest).write(to: directory.appendingPathComponent("newest.json"))
        try encoder.encode(older).write(to: directory.appendingPathComponent("older.json"))
        try encoder.encode(active).write(to: directory.appendingPathComponent("active.json"))
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent("broken.json"))

        let result = try await store.prune(referenceDate: reference)
        XCTAssertEqual(result.deletedRunIDs, ["older"])
        XCTAssertEqual(result.preservedActiveRunIDs, ["active"])
        XCTAssertEqual(result.corruptFileNames, ["broken.json"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("active.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("broken.json").path))
    }
}
