import Testing
@testable import TemplateVersion

struct TemplateVersionTests {
    @Test func modulesVersionIsSemantic() {
        let parts = TemplateVersion.modules.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) })
    }
}
