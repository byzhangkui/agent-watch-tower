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

            statusGuideTab
                .tabItem {
                    Label("Status Guide", systemImage: "circle.fill")
                }
        }
        .frame(width: 450, height: 360)
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

    // MARK: - Status Guide Tab

    @ViewBuilder
    private var statusGuideTab: some View {
        Form {
            Section("Session Status Indicators") {
                statusRow(
                    status: .running,
                    label: "Running",
                    description: "Agent is actively executing tools or writing code"
                )
                statusRow(
                    status: .thinking,
                    label: "Thinking",
                    description: "Agent is analyzing and generating a response"
                )
                statusRow(
                    status: .waitingForUser,
                    label: "Waiting for User",
                    description: "Agent needs your input to continue"
                )
                statusRow(
                    status: .idle,
                    label: "Idle",
                    description: "Session is idle with no active task"
                )
                statusRow(
                    status: .completed,
                    label: "Completed",
                    description: "Session finished successfully"
                )
                statusRow(
                    status: .error,
                    label: "Error",
                    description: "Session encountered an error"
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func statusRow(status: SessionStatus, label: String, description: String) -> some View {
        HStack(spacing: 10) {
            StatusIndicator(status: status)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
                            .fill(viewModel.claudeHooksInstalled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(viewModel.claudeHooksInstalled ? "Configured" : "Not configured")
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
                    if viewModel.claudeHooksInstalled {
                        Button("Uninstall Hooks") {
                            viewModel.uninstallClaudeHooks()
                        }
                    } else {
                        Button("Install Hooks") {
                            viewModel.installClaudeHooks()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()

                    Button("Test Connection") {
                        viewModel.testConnection()
                    }
                }
            }

            Section("Gemini CLI") {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.geminiHooksInstalled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(viewModel.geminiHooksInstalled ? "Configured" : "Not configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    if viewModel.geminiHooksInstalled {
                        Button("Uninstall Hooks") {
                            viewModel.uninstallGeminiHooks()
                        }
                    } else {
                        Button("Install Hooks") {
                            viewModel.installGeminiHooks()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    
                    Button("Test Connection") {
                        viewModel.testConnection()
                    }
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
