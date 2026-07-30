import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    private var animation: Animation {
        .interpolatingSpring(duration: 0.65, bounce: 0, initialVelocity: 0)
    }

    init(userDefaultService: UserDefaultService) {
        _viewModel = State(
            initialValue: OnboardingViewModel(userDefaultService: userDefaultService)
        )
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack {
                VStack(spacing: 10) {
                    GeometryReader { proxy in
                        let size = proxy.size

                        ScrollView(.horizontal) {
                            HStack(spacing: 0) {
                                ForEach(viewModel.onboardingItems.indices, id: \.self) { index in
                                    let currentItem = viewModel.onboardingItems[index]
                                    let isActive = viewModel.currentStage == index

                                    VStack(alignment: .center, spacing: 6) {
                                        Spacer()

                                        Image(currentItem.imagePath)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 256)

                                        Spacer()

                                        Text(currentItem.title)
                                            .font(.system(size: 30))
                                            .fontWeight(.bold)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(PassVaultColor.textPrimary)

                                        Text(currentItem.description)
                                            .font(.system(size: 16))
                                            .fontWeight(.regular)
                                            .lineLimit(4)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(PassVaultColor.textSecondary)
                                            .padding(.vertical, 16)
                                            .lineSpacing(12)
                                    }
                                    .padding(32)
                                    .frame(width: size.width)
                                    .compositingGroup()
                                    .blur(radius: isActive ? 0 : 30)
                                    .opacity(isActive ? 1 : 0)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .scrollDisabled(true)
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(
                            id: .init(
                                get: { viewModel.currentStage },
                                set: { _ in }
                            )
                        )
                    }

                    HStack(alignment: .center, spacing: 8) {
                        ForEach(viewModel.onboardingItems.indices, id: \.self) { index in
                            let isActive = viewModel.currentStage == index

                            Capsule()
                                .fill(isActive ? PassVaultColor.primary : PassVaultColor.border)
                                .frame(width: isActive ? 40 : 8, height: 8)
                                .animation(.bouncy(duration: 0.5), value: isActive)
                        }
                    }
                    .padding(.vertical, 10)

                    PassVaultButton(
                        title: viewModel.isLastStage ? "Get Started" : "Next",
                        variant: .primary,
                        action: {
                            withAnimation(animation) {
                                if viewModel.isLastStage {
                                    viewModel.onFinish()
                                } else {
                                    viewModel.onNext()
                                }
                            }
                        },
                        isEnabled: true
                    )
                    .padding(32)
                }
            }

            Button(action: {
                withAnimation(animation) {
                    viewModel.onBackPressed()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .frame(width: 20, height: 30)
            }
            .buttonBorderShape(.circle)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.bouncy(duration: 0.75), value: viewModel.currentStage != 0)
            .opacity(viewModel.currentStage != 0 ? 1 : 0)
            .padding(.leading, 20)
            .padding(.top, 5)
        }
    }
}

#Preview {
    OnboardingView(userDefaultService: UserDefaultService.shared)
}
