//
//  MainView.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import SwiftUI
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget

/// Main screen of the example app.
struct MainView: View {
    
    @ObservedObject var statusManager = GlobalPushStatusManager.shared
    @ObservedObject var tokenManager = GlobalTokenManager.shared
    @ObservedObject var boxManager = GlobalBoxModeManager.shared
    @EnvironmentObject var eventManager: EventManager

    @State private var creationDate: Date
    @State private var isSwitchOn = false
  
    init() {
        let storedDate = UserDefaults.standard.object(forKey: "tokenCreationDate") as? Date
        _creationDate = State(initialValue: storedDate ?? Date())
    }
    
    var body: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 0) {
                    VStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Image("altcraftclear")
                                    .resizable()
                                    .frame(width: 80, height: 16, alignment: .top)
                                    .padding(.leading, 20)
                                    .offset(y: 10)
                                    .offset(x: 10)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .offset(y: 10)

                            Spacer().frame(height: 15)

                            HStack(alignment: .top) {
                                VStack(spacing: 5) {
                                    ModuleCard(
                                        moduleName: "apns",
                                        imageName: "ic_apns_logo",
                                        status: tokenManager.provider == PushConstants.ProviderName.apns,
                                        onClick: {
                                            switchToAPNS()
                                        }
                                    )

                                    ModuleCard(
                                        moduleName: "fcm",
                                        imageName: "ic_fcm_logo",
                                        status: tokenManager.provider == PushConstants.ProviderName.firebase,
                                        onClick: {
                                            switchToFCM()
                                        }
                                    )

                                    ModuleCard(
                                        moduleName: "hms",
                                        imageName: "ic_hms_logo",
                                        status: tokenManager.provider == PushConstants.ProviderName.huawei,
                                        onClick: {
                                            switchToHMS()
                                        }
                                    )
                                }
                                .offset(x: 15, y: 25)

                                Spacer().frame(width: 12)

                                ZStack(alignment: .top) {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 5) {
                                            ForEach(0..<4, id: \.self) { index in
                                                createInfoItemView(
                                                    index: index,
                                                    token: getTokenSubString(of: tokenManager.token),
                                                    date: formattedDate
                                                )
                                                .padding(5)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .frame(height: 150)
                                    .background(Color.clear)
                                    .offset(y: 20)

                                    InfoStatusGrid(
                                        paddingHorizontal: 15,
                                        offsetX: 3,
                                        offsetY: 165
                                    )
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 280, alignment: .top)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 345, alignment: .top)
                        .background(Color.white)
                        .cornerRadius(30)
                        .offset(y: 30)
                    }

                    HStack {
                        Text("Subscribe status:")
                            .font(.system(size: 16))
                            .fontWeight(.bold)
                            .padding(.leading, 0)
                            .frame(width: 170, height: 30)

                        SubscribeStatusIndicator(status: statusManager.status)
                            .offset(x: -20)

                        Spacer()
                    }
                    .offset(y: -25)
                    .zIndex(10)

                    VStack {
                        Text("Actions:")
                            .font(.title)
                            .bold()
                            .padding(.top, 15)
                            .padding(.leading, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 10) {
                            ActionButton(
                                label: "Subscribe",
                                onClick: {
                                    boxManager.mode = AppConstants.BoxModeName.subscribe
                                },
                                customIcon: {
                                    AnyView(PlusIcon(lineWidth: 15, lineHeight: 3))
                                }
                            )
                            .frame(maxWidth: .infinity)

                            ActionButton(
                                label: "Profile",
                                onClick: {
                                    AltcraftSDK.push.subscription.current { _ in
                                        Task { @MainActor in
                                            boxManager.mode = AppConstants.BoxModeName.profile
                                        }
                                    }
                                },
                                customIcon: {
                                    AnyView(CommonIcon(rotationDegrees: 0, circleSize: 7))
                                }
                            )
                            .frame(maxWidth: .infinity)

                            ActionButton(
                                label: "Target",
                                onClick: {
                                    boxManager.mode = AppConstants.BoxModeName.target
                                },
                                customIcon: {
                                    AnyView(UShapedIcon())
                                }
                            )
                            .frame(maxWidth: .infinity)
                            
                            ActionButton(
                                label: "Clear",
                                onClick: {
                                    AltcraftSDK.clear {
                                        eventManager.clearEvents()
                                        JWTManager.shared.clearJWT()
                                        statusManager.clearStatus()
                                        statusManager.status = AppConstants.SubscriptionStatus.unsubscribed
                                    }
                                },
                                customIcon: {
                                    AnyView(
                                        XShapedIcon(
                                            lineWidth: 15,
                                            lineHeight: 3
                                        )
                                    )
                                },
                                accessibilityIdentifier: "home_clear_config_button"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 5)
                    }
                    .offset(y: -15)

                    Spacer().frame(height: 10)

                    VStack {
                        Text(getBoxName(mode: boxManager.mode))
                            .font(.title)
                            .bold()
                            .padding(.top, 20)
                            .padding(.leading, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        switch boxManager.mode {
                        case AppConstants.BoxModeName.subscribe:
                            SubBoxView(subscribe: true)

                        case AppConstants.BoxModeName.profile:
                            ProfileBoxView()

                        case AppConstants.BoxModeName.target:
                            MobileEventBoxView()

                        default:
                            MainEventsListView(events: eventManager.events)
                                .padding(.bottom, 20)
                                .offset(y: -10)
                        }
                    }
                    .offset(y: -15)
                }
                .background(Color.white)
            }.padding(.top, 10)
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            AltcraftSDK.inApp.setScreen(
                screen: "home"
            )
        }
    }
    
    private var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: creationDate)
    }
}

/// Previews for `MainView`.
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
