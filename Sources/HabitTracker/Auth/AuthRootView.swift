import SwiftUI

/// Full-screen auth gate. Single method (email OTP) so it's inlined here
/// instead of pushed via a method picker.
struct AuthRootView: View {
    @Bindable var coordinator: AuthCoordinator
    @State private var viewModel: EmailLoginViewModel?

    var body: some View {
        VStack(spacing: 32) {
            hero
            if let vm = viewModel {
                EmailLoginInlineForm(viewModel: vm)
            }
            if let error = coordinator.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            fineprint
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
        .onAppear {
            if viewModel == nil {
                viewModel = EmailLoginViewModel(auth: coordinator.auth) { [coordinator] id in
                    coordinator.didSignIn(userID: id)
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("WillPower")
                .font(.largeTitle.bold())
            Text("Budget time, not schedule it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var fineprint: some View {
        Text("By continuing, you agree to our Terms and Privacy Policy.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

/// Inline form used by `AuthRootView`; same VM as `EmailLoginView` but
/// without the navigation chrome — it's already inside the root.
private struct EmailLoginInlineForm: View {
    @Bindable var viewModel: EmailLoginViewModel

    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.step {
            case .email: emailStep
            case .code:  codeStep
            }
            if let error = viewModel.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var emailStep: some View {
        VStack(spacing: 12) {
            Text("Enter your email to get a 6-digit code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("you@example.com", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await viewModel.sendCode() }
            } label: {
                if viewModel.inFlight {
                    ProgressView()
                } else {
                    Text("Send code").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.email.isEmpty || viewModel.inFlight)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    viewModel.backToEmail()
                } label: {
                    Label("Use a different email", systemImage: "chevron.left")
                        .font(.subheadline)
                }
                Spacer()
            }
            Text("Enter the code we sent to\n\(viewModel.email)")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            TextField("123456", text: $viewModel.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
            Button {
                Task { await viewModel.verify() }
            } label: {
                if viewModel.inFlight {
                    ProgressView()
                } else {
                    Text("Verify").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.code.isEmpty || viewModel.inFlight)
            resendRow
        }
    }

    private var resendRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = viewModel.resendSecondsRemaining(at: context.date)
            HStack(spacing: 4) {
                Text("Didn't get the email?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if remaining > 0 {
                    Text("Resend in \(remaining)s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Resend code") {
                        Task { await viewModel.sendCode() }
                    }
                    .font(.caption.weight(.semibold))
                    .disabled(viewModel.inFlight)
                }
            }
        }
    }
}
