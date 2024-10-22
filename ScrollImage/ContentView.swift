//
//  ContentView.swift
//  ScrollImage
//
//  Created by shiyanjun on 2024/7/18.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            NavigationLink {
                ScrollImageViewExample()
            } label: {
                Text("查看照片")
            }
            .navigationTitle("首页")
        }
    }
}

#Preview {
    ContentView()
}
