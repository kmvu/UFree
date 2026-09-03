//
//  UFreeType.swift
//  UFree
//
//  Shared typography for hero surfaces and product CTAs.
//

import SwiftUI

enum UFreeType {
    static let heroTitle = Font.system(.title2, design: .rounded).weight(.bold)
    static let heroBody = Font.body
    static let ctaLabel = Font.subheadline.weight(.semibold)
    static let compactCTALabel = Font.footnote.weight(.semibold)
}
