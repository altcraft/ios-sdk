//
//  MainView.swift
//
//  IOSAPNsApp
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import SwiftUI
import Altcraft

struct MainView: View {
    
    @ObservedObject var tokenManager = GlobalTokenManager.shared
    @ObservedObject var statusManager = GlobalStatusManager.shared
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
                    .frame(maxWidth: .infinity, alignment: .leading).offset(y: 10)
                    
                    Spacer().frame(height: 15)
                    
                    HStack {
                        VStack(spacing: 10) {
                            ModuleCard(
                                moduleName: "apns",
                                imageName: "ic_apns_logo",
                                status: tokenManager.provider == Constants.ProviderName.apns,
                                onClick: {
                                    switchToAPNS()
                                }
                            )
                            ModuleCard(
                                moduleName: "fcm",
                                imageName: "ic_fcm_logo",
                                status: tokenManager.provider == Constants.ProviderName.firebase,
                                onClick: {
                                    switchToFCM()
                                }
                            )
                            ModuleCard(
                                moduleName: "hms",
                                imageName: "ic_hms_logo",
                                status:  tokenManager.provider == Constants.ProviderName.huawei,
                                onClick: {
                                    switchToHMS()
                                }
                            )
                        }.offset(x: 15, y: 25)
                        
                        Spacer().frame(width: 15)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(0..<3, id: \.self) { index in
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
                        .offset(y: -12)
                    }
// qa test ui ------------------------------------------------------------------------
//                    HStack {
//                        Spacer()
//                        Toggle(isOn: $isSwitchOn) {
//                            Text("QA")
//                                .font(.system(size: 10))
//                                .bold()
//                                .multilineTextAlignment(.center)
//                        }
//                        .toggleStyle(CustomSwitchStyle())
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: 30, alignment: .trailing)
//                    .offset(x: -15, y: -5)
//                }
//                .onChange(of: isSwitchOn) { newValue in
//                    if newValue {
//                        getResTokenTest()
//                    } else {
//                        stopResTokenTest()
//                    }
// qa test ui--------------------------------------------------------------------------
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(Color.white)
                .cornerRadius(30)
                .shadow(radius: 10)
                .offset(y: 0)
                .alignmentGuide(.top) { _ in 0 }

                
                Spacer()
                
                ScrollView {
                    VStack {
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
                        .padding(.top, 10)
                        
                        VStack {
                            Text("Actions:")
                                .font(.title)
                                .bold()
                                .padding(.top, 10)
                                .padding(.leading, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 10)  {
                                ActionButton(label: "Subscribe to push", onClick: {
                                    boxManager.mode = AppConstants.BoxModeName.subscribe
                                }, customIcon: {
                                    AnyView(PlusIcon(lineWidth: 15, lineHeight: 3))
                                })
                                .frame(maxWidth: .infinity)
                                
                                
                                ActionButton(label: "Get profile status", onClick: {
                                    AltcraftSDK.shared.pushSubscriptionFunctions.getStatusForCurrentSubscription{ _ in
                                        Task { @MainActor in
                                            boxManager.mode = AppConstants.BoxModeName.profile
                                        }
                                    }
                                },customIcon: {AnyView(CommonIcon( rotationDegrees: 0,circleSize: 7))
                                    
                                }).frame(maxWidth: .infinity)
                                
                                
                                ActionButton(label: "update device token", onClick: {
                                    
                                    AltcraftSDK.shared.pushTokenFunction.forcedTokenUpdate()
                                    //Update
                                }, customIcon: {
                                    AnyView(UShapedIcon())
                                }).frame(maxWidth: .infinity)
                                
                                ActionButton(label: "Clear SDK cache", onClick: {
                                    
                                    AltcraftSDK.shared.clear {
                                        eventManager.clearEvents()
                                        JWTManager.shared.setJWT(JWTManager.shared.getAnonJWT())
                                        statusManager.clearStatus()
                                        statusManager.status = AppConstants.SubscriptionStatus.unsubscribed
                                    }

                                }, customIcon: {
                                    AnyView(XShapedIcon(lineWidth: 15, lineHeight: 3))
                                }).frame(maxWidth: .infinity)
                            }
                            .padding(.top, 5)
                            .offset(y: 0)
                        }
                        
                        Spacer().frame(height: 10)
                        
                        VStack {
                            Text(getBoxName(mode: boxManager.mode))
                                .font(.title)
                                .bold()
                                .padding(.top, 20)
                                .padding(.leading, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            switch boxManager.mode {
                            case 
                                AppConstants.BoxModeName.subscribe: SubBoxView(subscribe: true)
                                
                            case 
                                AppConstants.BoxModeName.profile: ProfileBoxView()
        
                            default:
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 5) {
                                            ForEach(eventManager.events) { identifiable in
                                                MainEventsView(
                                                    eventMessage: "\(identifiable.event.function): \(identifiable.event.message ?? "")",
                                                    eventCode: identifiable.event.eventCode ?? 0,
                                                    eventDate: identifiable.event.date
                                                )
                                                .padding(5)
                                                .id(identifiable.id)
                                            }
                                        }
                                    }
                                    .onChange(of: eventManager.events) { events in
                                        if let last = events.last {
                                            DispatchQueue.main.async {
                                                proxy.scrollTo(last.id, anchor: .trailing)
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, 10)
                                .frame(height: 150)
                                .background(Color.white)
                                .offset(y: 0)
                            }
                        }
                    }
                }
            }
            .background(Color.white)
            
            Spacer().frame(height: 15)
        }
        .edgesIgnoringSafeArea(.top)
    }
    
    private var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: creationDate)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}   








