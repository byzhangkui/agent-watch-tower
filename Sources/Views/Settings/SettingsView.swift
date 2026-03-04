#if canImport(AppKit)
import SwiftUI

/// Application settings window.
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            agentsTab
                .tabItem {
                    Label("Agents", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
        .frame(width: 450, height: 300)
        .alert("Hook Configuration", isPresented: $viewModel.showInstallAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section("Data") {
                HStack {
                    Text("Event retention")
                    Spacer()
                    Picker("", selection: $viewModel.retentionDays) {
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .frame(width: 120)
                }

                HStack {
                    Text("Database location")
                    Spacer()
                    Text(Constants.databaseDirectory.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Section("Server") {
                HStack {
                    Text("HTTP port")
                    Spacer()
                    Text("\(Constants.httpPort)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Agents Tab

    @ViewBuilder
    private var agentsTab: some View {
        Form {
            Section("Claude Code") {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.hooksInstalled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(viewModel.hooksInstalled ? "Configured" : "Not configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Hook port")
                    Spacer()
                    Text("\(Constants.httpPort)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if viewModel.hooksInstalled {
                        Button("Uninstall Hooks") {
                            viewModel.uninstallHooks()
                        }
                    } else {
                        Button("Install Hooks") {
                            viewModel.installHooks()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()

                    Button("Test Connection") {
                        viewModel.testConnection()
                    }
                }
            }

            Section("Gemini") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            viewModel.checkHookStatus()
        }
    }
}
#endif
