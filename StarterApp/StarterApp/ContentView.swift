//
//  ContentView.swift
//  StarterApp
//
//

import SwiftUI
// Modules are optional per project.yml; reference them only under canImport.
#if canImport(TemplateVersion)
import TemplateVersion
#endif
#if canImport(Theme)
import Theme
#endif

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            details
        }
        .padding()
    }

    /// Build details under the greeting: on a themed card when the Theme module is enabled, plain otherwise.
    @ViewBuilder private var details: some View {
#if canImport(Theme)
        ThemedCard { detailLines }
#else
        detailLines
#endif
    }

    @ViewBuilder private var detailLines: some View {
        VStack(spacing: 4) {
            Text("Built on GitHub Actions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
#if canImport(TemplateVersion)
            Text("Modules \(TemplateVersion.modules)")
                .font(.footnote)
                .foregroundStyle(.secondary)
#endif
        }
    }
}

#Preview {
    ContentView()
}
