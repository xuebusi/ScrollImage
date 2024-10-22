//
//  ScrollImageView.swift
//  ScrollImage
//
//  Created by shiyanjun on 2024/7/18.
//

import SwiftUI
import Photos

struct Photo: Identifiable, Hashable {
    var id: String { localIdentifier }
    var localIdentifier: String
    var asset: PHAsset
    var uiImage: UIImage?
    
    init(asset: PHAsset) {
        self.localIdentifier = asset.localIdentifier
        self.asset = asset
    }
}

class PhotoViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    
    private lazy var requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        return options
    }()
    
    init() {
        requestPhotoLibraryAccess()
    }
    
    private func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                self.fetchPhotos()
            }
        }
    }
    
    func fetchPhotos() {
        let assets = fetchAssets()
        for asset in assets {
            // 检查是否已经存在相同的localIdentifier
            if !photos.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                /**
                 通过DispatchQueue.main.asyncAfter延迟执行，可以有效缓解内存飙升的现象，
                 因为这给系统和ARC机制更多时间来回收内存，同时避免了主线程频繁刷新UI的高负载。
                 这种技巧在处理大量数据初始化或大规模UI更新时非常实用，能显著提升应用的性能和稳定性。
                 */
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.photos.append(Photo(asset: asset))
                }
            }
        }
    }
    
    private func fetchAssets() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // 获取资源
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        let assets = fetchResult.objects(at: IndexSet(integersIn: 0..<fetchResult.count))
        return assets
    }
    
    func loadImage(from asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { image, _ in
            completion(image)
        }
    }
}

/// - ScrollImageViw 使用示例
struct ScrollImageViewExample: View {
    @StateObject var vm = PhotoViewModel()
    @State private var currentIndex: Int = 0
    
    let requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        return options
    }()
    
    let targetSize = CGSize(width: 1024, height: 1024)
    
    var body: some View {
        ScrollImageView(list: vm.photos, currentIndex: $currentIndex) { photo in
            Group {
                if let uiImage = photo.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(10)
                        .padding(.horizontal, 5)
                } else {
                    Color.clear
                        .onAppear {
                            vm.loadImage(from: photo.asset, size: targetSize) { uiImage in
                                if let uiImage = uiImage {
                                    if let index = vm.photos.firstIndex(where: { $0.id == photo.id }) {
                                        vm.photos[index].uiImage = uiImage
                                    }
                                }
                            }
                        }
                }
            }
        }
        .navigationTitle("我的照片")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            pageView()
        }
        .onChange(of: currentIndex) { _, newIndex in
            if newIndex >= 2 {
                vm.photos[newIndex - 2].uiImage = nil
                print("卸载索引\(newIndex - 2)")
            }
            if newIndex <= vm.photos.count - 3 {
                vm.photos[newIndex + 2].uiImage = nil
                print("卸载索引\(newIndex + 2)")
            }
        }
    }
    
    /// - 页码
    private func pageView() -> some View {
        Text("\(currentIndex) / \(vm.photos.count - 1)")
            .font(.headline)
            .padding(.bottom, 50)
    }
}

/// - 双向滚动视图
struct ScrollImageView<Content: View, T: Identifiable>: View {
    let list: [T]
    @Binding var currentIndex: Int
    @State private var offset: CGSize = .zero
    @State private var direction: Direction = .none
    
    var content: (T) -> Content
    
    init(list: [T], currentIndex: Binding<Int>, @ViewBuilder content: @escaping (T) -> Content) {
        self.list = list
        self._currentIndex = currentIndex
        self.content = content
    }
    
    /// - 手势方向
    enum Direction {
        case h, v, none
    }
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            AxisCurrentPageView(list: list, currentIndex: $currentIndex, content: content)
                .offset(x: offset.width, y: offset.height)
                .gesture(
                    DragGesture()
                        .onChanged({ value in
                            let trans = value.translation
                            if direction == .none {
                                direction = abs(trans.width) > abs(trans.height) ? .h : .v
                            }
                            
                            if direction == .h {
                                offset = CGSize(width: trans.width, height: 0)
                            } else if direction == .v {
                                offset = CGSize(width: 0, height: trans.height)
                            }
                        })
                        .onEnded({ value in
                            let pageSize = direction == .h ? size.width : size.height
                            let translation = direction == .h ? value.translation.width : value.translation.height
                            
                            /// - 值为负数时表示向上或向左滑动，值为正数时表示向下或向右滑动
                            let dir = Int(translation / abs(translation))
                            
                            if abs(translation) > pageSize * 0.1 && !isAtBoundary(dir: dir) {
                                let newOffset = CGSize(
                                    width: direction == .h ? CGFloat(dir) * pageSize : 0,
                                    height: direction == .v ? CGFloat(dir) * pageSize : 0
                                )
                                
                                withAnimation(.interactiveSpring) {
                                    offset = newOffset
                                } completion: {
                                    if direction == .h {
                                        if translation < 0 {
                                            currentIndex = max(min(currentIndex + 1, list.count - 1), 0)
                                        } else {
                                            currentIndex = max(min(currentIndex - 1, list.count - 1), 0)
                                        }
                                    } else {
                                        if translation < 0 {
                                            currentIndex = max(min(currentIndex + 1, list.count - 1), 0)
                                        } else {
                                            currentIndex = max(min(currentIndex - 1, list.count - 1), 0)
                                        }
                                    }
                                    direction = .none
                                }
                            } else {
                                withAnimation(.interactiveSpring) {
                                    offset = .zero
                                    direction = .none
                                }
                            }
                        })
                )
                .onChange(of: currentIndex) {
                    offset = .zero
                }
        }
    }
    
    /// - 是否到达边界 (第一页或最后一页)
    private func isAtBoundary(dir: Int) -> Bool {
        /// - 第一页向下或向右滑 || 最后一页向上或向左滑
        return (currentIndex == 0 && dir > 0) || (currentIndex == list.count - 1 && dir < 0)
    }
}

/// - 当前页
struct AxisCurrentPageView<Content: View, T: Identifiable>: View {
    let list: [T]
    @Binding var currentIndex: Int
    
    var content: (T) -> Content
    
    init(list: [T], currentIndex: Binding<Int>, content: @escaping (T) -> Content) {
        self.list = list
        self._currentIndex = currentIndex
        self.content = content
    }
    
    var body: some View {
        Color.clear
            .overlay(alignment: .center) {
                getPage(pageIndex: currentIndex)
            }
            .overlay(alignment: .top) {
                getPage(pageIndex: currentIndex - 1)
                    .alignmentGuide(.top) { $0[.bottom]}
            }
            .overlay(alignment: .bottom) {
                getPage(pageIndex: currentIndex + 1)
                    .alignmentGuide(.bottom) { $0[.top]}
            }
            .overlay(alignment: .leading) {
                getPage(pageIndex: currentIndex - 1)
                    .alignmentGuide(.leading) { $0[.trailing]}
            }
            .overlay(alignment: .trailing) {
                getPage(pageIndex: currentIndex + 1)
                    .alignmentGuide(.trailing) { $0[.leading]}
            }
            .contentShape(Rectangle())
    }
    
    /// - 根据索引获取页面
    private func getPage(pageIndex: Int) -> some View {
        Group {
            if (0 ..< list.count).contains(pageIndex)  {
                Color.clear
                    .overlay {
                        content(list[pageIndex])
                    }
            }
        }
    }
}


#Preview {
    ScrollImageViewExample()
        .preferredColorScheme(.dark)
}
