//
//  SwiftUIView.swift
//  ScrollImage
//
//  Created by shiyanjun on 2024/10/23.
//

import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        GeometryReader {
            let size = $0.size
            ZStack {
                Image("m1")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .offset(x: -100)
                
                Image("m2")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                
                Image("m3")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .offset(x: 100)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

#Preview {
    SwiftUIView()
        .preferredColorScheme(.dark)
}
