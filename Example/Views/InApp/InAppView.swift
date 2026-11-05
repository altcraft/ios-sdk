//
//  InAppView.swift
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

/// In-app campaigns screen.
struct InAppView: View {
    private let dividerColor = Color(
        red: 0.88,
        green: 0.88,
        blue: 0.88
    )

    @ObservedObject private var placementManager =
        GlobalInAppPlacementManager.shared

    var body: some View {
        VStack(spacing: 0) {
            Header()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    PlacementCell(
                        placementCount: placementManager.placementCount
                    )

                    DividerView(
                        color: dividerColor
                    )

                    InAppIconCell(
                        imageName: "ic_in_app_center",
                        title: "Modal",
                        trigger: "tr_modal"
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

                HorizontalDividerView(
                    color: dividerColor
                )

                HStack(spacing: 0) {
                    InAppIconCell(
                        imageName: "ic_in_app_fullscreen",
                        title: "Fullscreen",
                        trigger: "tr_fullscreen"
                    )

                    DividerView(
                        color: dividerColor
                    )

                    InAppIconCell(
                        imageName: "ic_in_app_down",
                        title: "Floating Bar",
                        trigger: "tr_floating_bar"
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

                HorizontalDividerView(
                    color: dividerColor
                )

                HStack(spacing: 0) {
                    InAppIconCell(
                        imageName: "ic_in_app_top",
                        title: "SlideUp",
                        trigger: "tr_slide_up"
                    )

                    DividerView(
                        color: dividerColor
                    )

                    InAppIconCell(
                        imageName: "ic_in_app_custom",
                        title: "Custom",
                        trigger: "tr_custom"
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
            .padding(15)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
        .background(Color.white)
        .ignoresSafeArea(
            .container,
            edges: .top
        )
        .onAppear {
            AltcraftSDK.inApp.setScreen(
                screen: "inapp"
            )
        }
    }
}

/// Placement list cell.
private struct PlacementCell: View {
    let placementCount: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Placements")
                .font(
                    .system(
                        size: 14,
                        weight: .bold
                    )
                )
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            ZStack(alignment: .topTrailing) {
                Image("ic_in_app_download")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .frame(
                        width: 120,
                        height: 120
                    )
                    .onTapGesture {
                        AltcraftSDK
                            .inApp
                            .getPlacements()
                    }

                if placementCount > 0 {
                    CountBadge(
                        count: placementCount
                    )
                    .offset(
                        x: -2,
                        y: 0
                    )
                }
            }
            .frame(
                width: 120,
                height: 120
            )

            Text("Load placements")
                .font(
                    .system(size: 11)
                )
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}

/// Placement icon cell.
private struct InAppIconCell: View {
    let imageName: String
    let title: String
    let trigger: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(
                    .system(
                        size: 14,
                        weight: .bold
                    )
                )
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .padding(8)
                .frame(
                    width: 120,
                    height: 120
                )
                .onTapGesture {
                    AltcraftSDK
                        .inApp
                        .trigger(
                            name: trigger
                        )
                }

            Text(trigger)
                .font(
                    .system(size: 11)
                )
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}

/// Placement count badge.
private struct CountBadge: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(
                    width: 20,
                    height: 20
                )

            Circle()
                .fill(Color.black)
                .frame(
                    width: 18,
                    height: 18
                )

            Text("\(count)")
                .font(
                    .system(
                        size: 10,
                        weight: .bold
                    )
                )
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }
}

/// List divider.
private struct DividerView: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 2)
            .padding(
                .vertical,
                15
            )
    }
}

/// Horizontal list divider.
private struct HorizontalDividerView: View {
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(height: 2)

            Color.clear
                .frame(
                    width: 60,
                    height: 2
                )

            Rectangle()
                .fill(color)
                .frame(height: 2)
        }
        .padding(
            .horizontal,
            15
        )
        .frame(maxWidth: .infinity)
        .frame(height: 2)
    }
}
