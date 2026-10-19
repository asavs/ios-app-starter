import Foundation
import SwiftUI
import Testing
@testable import Onboarding

struct OnboardingTests {
    /// A throwaway defaults domain so tests never touch the host's standard defaults.
    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "OnboardingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func pagesDefaultTheirIdentityToTheTitle() {
        let page = OnboardingPage(systemImage: "star", title: "Hello", message: "World")
        #expect(page.id == "Hello")
        #expect(OnboardingPage(id: "custom", systemImage: "star", title: "Hello", message: "World").id == "custom")
    }

    @Test func templateDefaultsAreDistinctAndComplete() {
        let pages = OnboardingPage.templateDefaults
        #expect(pages.count == 3)
        #expect(Set(pages.map(\.id)).count == pages.count)
        for page in pages {
            #expect(!page.systemImage.isEmpty)
            #expect(!page.title.isEmpty)
            #expect(!page.message.isEmpty)
        }
    }

    @Test func pagerAdvancesToTheLastPageThenFinishes() {
        var pager = OnboardingPager(pageCount: 3)
        #expect(pager.index == 0)
        #expect(!pager.isLast)
        #expect(pager.progress == 1.0 / 3.0)
        let firstStep = pager.advance()
        let secondStep = pager.advance()
        #expect(!firstStep && !secondStep)
        #expect(pager.isLast)
        #expect(pager.index == 2)
        #expect(pager.progress == 1)
        let finished = pager.advance()
        #expect(finished)
        #expect(pager.index == 2)
    }

    @Test func pagerClampsSelectionAndHandlesNoPages() {
        var pager = OnboardingPager(pageCount: 2)
        pager.select(9)
        #expect(pager.index == 1)
        pager.select(-4)
        #expect(pager.index == 0)
        #expect(OnboardingPager(pageCount: 3, index: 7).index == 2)

        var empty = OnboardingPager(pageCount: 0)
        #expect(empty.isLast)
        #expect(empty.progress == 1)
        let finished = empty.advance()
        #expect(finished)
        #expect(empty.index == 0)
        #expect(OnboardingPager(pageCount: -2).pageCount == 0)
    }

    @Test func recordStartsIncompleteAndRemembersCompletion() throws {
        let record = OnboardingRecord(defaults: try isolatedDefaults())
        #expect(record.completedVersion == 0)
        #expect(!record.isComplete(version: 1))
        record.markComplete(version: 1)
        #expect(record.isComplete(version: 1))
        #expect(record.completedVersion == 1)
    }

    @Test func raisingTheVersionShowsTheFlowAgain() throws {
        let record = OnboardingRecord(defaults: try isolatedDefaults())
        record.markComplete(version: 1)
        #expect(!record.isComplete(version: 2))
        record.markComplete(version: 2)
        #expect(record.isComplete(version: 1))
        #expect(record.isComplete(version: 2))
        record.markComplete(version: 1) // Never lowers an earlier completion.
        #expect(record.completedVersion == 2)
    }

    @Test func resetForgetsCompletion() throws {
        let record = OnboardingRecord(defaults: try isolatedDefaults())
        record.markComplete(version: 3)
        record.reset()
        #expect(record.completedVersion == 0)
        #expect(!record.isComplete(version: 1))
    }

    @Test func recordKeyIsStableForLaunchArguments() throws {
        #expect(OnboardingRecord.defaultKey == "onboarding.completedVersion")
        #expect(OnboardingRecord(defaults: try isolatedDefaults()).key == OnboardingRecord.defaultKey)
        let custom = OnboardingRecord(defaults: try isolatedDefaults(), key: "tour.version")
        #expect(custom.key == "tour.version")
    }

    @Test @MainActor func viewsConstructWithPublicInitializers() throws {
        let pages = OnboardingPage.templateDefaults
        _ = OnboardingPageView(pages[0])
        _ = OnboardingView(pages: pages) {}
        _ = OnboardingView(pages: pages, skipTitle: nil, continueTitle: "Next", finishTitle: "Done") {}
        _ = Text("Content").onboardingGate(pages: pages)
        _ = Text("Content").onboardingGate(pages: [], version: 2,
                                           record: OnboardingRecord(defaults: try isolatedDefaults()))
    }
}
