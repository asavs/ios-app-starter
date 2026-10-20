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

    @Test func templateStepsShowEachKindOnceWithDistinctIdentity() {
        let steps = OnboardingStep.templateDefaults
        #expect(steps.count == 3)
        #expect(Set(steps.map(\.id)).count == steps.count)
        guard case .welcome(let welcome) = steps[0].kind else { Issue.record("first step should be the welcome sheet"); return }
        #expect(welcome.features.count == 3)
        #expect(Set(welcome.features.map(\.id)).count == welcome.features.count)
        guard case .page = steps[1].kind else { Issue.record("second step should be a tour card"); return }
        guard case .permission(let primer) = steps[2].kind else { Issue.record("last step should be the permission primer"); return }
        #expect(primer.continueTitle == "Continue")
        #expect(primer.page.id == primer.id)
    }

    @Test func skipShowsExceptOnPermissionStepsAndTheLastStep() {
        let page = OnboardingStep.page(OnboardingPage(systemImage: "star", title: "Tour", message: "..."))
        let primer = PermissionPrimer(id: "notifications", systemImage: "bell", title: "Alerts", message: "...",
                                      requester: FakePermission())
        let permission = OnboardingStep.permission(primer)
        #expect(page.allowsSkip)
        #expect(page.showsSkip(isLast: false))
        #expect(!page.showsSkip(isLast: true))
        #expect(!permission.allowsSkip)
        #expect(!permission.showsSkip(isLast: false))
        #expect(OnboardingStep.permission(primer, allowsSkip: true).showsSkip(isLast: false))
        #expect(OnboardingStep.welcome(WelcomeContent(title: "Hi")).id == "welcome")
        #expect(page.id == "Tour")
    }

    @Test func pagesBridgeKeepsOrderAndIdentity() {
        let pages = OnboardingPage.templateDefaults
        let steps = OnboardingStep.pages(pages)
        #expect(steps.map(\.id) == pages.map(\.id))
        for (step, page) in zip(steps, pages) {
            guard case .page(let wrapped) = step.kind else { Issue.record("expected a page step"); continue }
            #expect(wrapped == page)
        }
    }

    @Test func continueTitleComesFromTheStepThenThePrimerThenTheFlow() {
        let page = OnboardingStep.page(OnboardingPage(systemImage: "star", title: "Tour", message: "..."))
        let named = OnboardingStep.page(OnboardingPage(systemImage: "star", title: "Named", message: "..."),
                                        continueTitle: "Let's go")
        let primer = PermissionPrimer(id: "n", systemImage: "bell", title: "Alerts", message: "...",
                                      continueTitle: "Next", requester: FakePermission())
        let permission = OnboardingStep.permission(primer)
        func title(_ step: OnboardingStep?, isLast: Bool) -> String {
            OnboardingView.buttonTitle(for: step, isLast: isLast, continueTitle: "Continue", finishTitle: "Done")
        }
        #expect(title(page, isLast: false) == "Continue")
        #expect(title(page, isLast: true) == "Done")
        #expect(title(named, isLast: true) == "Let's go")
        #expect(title(permission, isLast: false) == "Next")
        #expect(title(permission, isLast: true) == "Next")
        #expect(title(nil, isLast: true) == "Done")
    }

    @Test func fakePermissionReportsItsOutcome() async {
        #expect(await FakePermission().request() == .granted)
        #expect(await FakePermission(outcome: .denied).request() == .denied)
        #expect(await FakePermission(outcome: .unavailable, delay: .milliseconds(1)).request() == .unavailable)
    }

    @Test func permissionOverrideReplacesTheRealRequesterOnlyWhenSet() async throws {
        struct Probe: PermissionRequesting {
            func request() async -> PermissionOutcome { .unavailable }
        }
        let defaults = try isolatedDefaults()
        #expect(PermissionOverride.defaultKey == "onboarding.permissions")
        let untouched = PermissionOverride.resolve(real: Probe(), defaults: defaults)
        #expect(untouched is Probe)
        defaults.set("denied", forKey: PermissionOverride.defaultKey)
        let faked = PermissionOverride.resolve(real: Probe(), defaults: defaults)
        #expect(faked is FakePermission)
        #expect(await faked.request() == .denied)
        defaults.set("maybe", forKey: PermissionOverride.defaultKey)
        #expect(PermissionOverride.resolve(real: Probe(), defaults: defaults) is Probe)
    }

    @Test @MainActor func viewsConstructWithPublicInitializers() throws {
        let pages = OnboardingPage.templateDefaults
        let steps = OnboardingStep.templateDefaults
        _ = OnboardingPageView(pages[0])
        if case .welcome(let content) = steps[0].kind {
            _ = WelcomeStepView(content)
            _ = WelcomeFeatureRow(content.features[0])
        }
        if case .permission(let primer) = steps[2].kind {
            _ = PermissionStepView(primer)
        }
        _ = OnboardingView(pages: pages) {}
        _ = OnboardingView(steps: steps) {}
        _ = OnboardingView(steps: steps, skipTitle: nil, continueTitle: "Next", finishTitle: "Done") {}
        _ = OnboardingStep.custom(id: "extra") { Text("Anything") }
        _ = Text("Content").onboardingGate(pages: pages)
        _ = Text("Content").onboardingGate(steps: steps)
        _ = Text("Content").onboardingGate(steps: [], version: 2,
                                           record: OnboardingRecord(defaults: try isolatedDefaults()))
    }
}
