import SwiftUI
import UIKit

struct VideoPosterThumbnailView: View {
    let url: URL
    var reloadToken: Int = 0

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: 84, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "play.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(4)
                .background(.black.opacity(0.45), in: Circle())
                .padding(4)
        }
        .task(id: "\(url.path)|\(reloadToken)") {
            image = await VideoPosterThumbnailCache.image(for: url)
        }
    }
}
