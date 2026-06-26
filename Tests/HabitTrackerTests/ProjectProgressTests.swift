import XCTest
@testable import HabitTracker

final class ProjectProgressTests: XCTestCase {
    func test_progress_noMilestones_isZero() {
        let project = Project(title: "Empty")
        XCTAssertEqual(project.progress, 0)
        XCTAssertEqual(project.totalMilestones, 0)
        XCTAssertEqual(project.completedMilestones, 0)
    }

    func test_progress_halfComplete() {
        let m1 = Milestone(title: "Outline", isCompleted: true)
        let m2 = Milestone(title: "Draft", isCompleted: true)
        let m3 = Milestone(title: "Edit")
        let m4 = Milestone(title: "Publish")
        let project = Project(title: "Book", milestones: [m1, m2, m3, m4])

        XCTAssertEqual(project.totalMilestones, 4)
        XCTAssertEqual(project.completedMilestones, 2)
        XCTAssertEqual(project.progress, 0.5)
    }

    func test_progress_allComplete_isOne() {
        let project = Project(
            title: "Done",
            milestones: [
                Milestone(title: "A", isCompleted: true),
                Milestone(title: "B", isCompleted: true)
            ]
        )
        XCTAssertEqual(project.progress, 1.0)
    }

    func test_markCompleted_updatesProgress() {
        let m = Milestone(title: "Ship")
        let project = Project(title: "Launch", milestones: [m])
        XCTAssertEqual(project.progress, 0)

        m.markCompleted()
        XCTAssertEqual(project.progress, 1.0)
        XCTAssertNotNil(m.completedAt)

        m.markIncomplete()
        XCTAssertEqual(project.progress, 0)
        XCTAssertNil(m.completedAt)
    }
}
