//
//  HTMLNode.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation

struct HTMLNode: Identifiable, Decodable {
    let id: Int
    let name: String
    let attributes: String
    let children: [HTMLNode]?

    var displayName: String {
        "<\(name)\(attributes)>"
    }
}
