//
//  MeowbahWidgetExtensionBundle.swift
//  MeowbahWidgetExtension
//
//  Created by Ryan Reid on 21/02/2026.
//

import WidgetKit
import SwiftUI

@main
struct MeowbahWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        MeowbahMostRecentVideoWidget()
        MeowTalkWidget()
    }
}
