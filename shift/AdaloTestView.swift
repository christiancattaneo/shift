import SwiftUI

struct AdaloTestView: View {
    @StateObject private var imageService = AdaloImageService()
    @StateObject private var downloader = AdaloImageDownloader.shared
    @State private var selectedImageInfo: AdaloImageService.AdaloImageInfo?
    @State private var showingImageDetail = false
    @State private var searchText = ""
    @State private var selectedSource: String = "All"
    @State private var showingExportOptions = false
    @State private var showingDownloadOptions = false
    
    private let sources = ["All", "user", "event", "place"]
    
    var filteredImages: [AdaloImageService.AdaloImageInfo] {
        let sourceFiltered = selectedSource == "All" ? imageService.allImages : imageService.allImages.filter { $0.source == selectedSource }
        
        if searchText.isEmpty {
            return sourceFiltered
        } else {
            return sourceFiltered.filter { 
                $0.filename?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.url.localizedCaseInsensitiveContains(searchText) ||
                $0.source.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Stats
                if !imageService.allImages.isEmpty {
                    HStack {
                        StatCard(title: "Total Images", value: "\(imageService.allImages.count)")
                        StatCard(title: "Total Size", value: {
                            let totalSize = imageService.getTotalImageSize()
                            return totalSize > 0 ? ByteCountFormatter().string(fromByteCount: Int64(totalSize)) : "0 bytes"
                        }())
                        StatCard(title: "Filtered", value: "\(filteredImages.count)")
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                // Controls
                VStack(spacing: 12) {
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    // Filter & Action Controls
                    VStack(spacing: 12) {
                        // Source Filter
                        Picker("Source", selection: $selectedSource) {
                            ForEach(sources, id: \.self) { source in
                                Text(source.capitalized).tag(source)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        // Action Buttons
                        HStack(spacing: 15) {
                            // Export Button
                            Button(action: { showingExportOptions = true }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .disabled(imageService.allImages.isEmpty)
                            
                            // Download Button
                            Button(action: { showingDownloadOptions = true }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Download")
                                }
                                .font(.caption)
                                .foregroundColor(.green)
                            }
                            .disabled(imageService.allImages.isEmpty || downloader.isDownloading)
                            
                            Spacer()
                            
                            // Downloaded Count (if any)
                            if !downloader.downloadedImages.isEmpty {
                                Text("\(downloader.downloadedImages.count) downloaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // Content
                if imageService.isLoading {
                    LoadingView(progress: imageService.progress)
                } else if downloader.isDownloading {
                    DownloadProgressView(downloader: downloader)
                } else if imageService.allImages.isEmpty {
                    EmptyStateView {
                        imageService.fetchAllImages()
                    }
                } else {
                    ImageGridView(images: filteredImages) { imageInfo in
                        selectedImageInfo = imageInfo
                        showingImageDetail = true
                    }
                }
                
                if let errorMessage = imageService.errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
            .navigationTitle("All Adalo Images")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        imageService.fetchAllImages()
                    }
                    .disabled(imageService.isLoading)
                }
            }
        }
        .onAppear {
            if imageService.allImages.isEmpty {
                imageService.fetchAllImages()
            }
        }
        .sheet(isPresented: $showingImageDetail) {
            if let imageInfo = selectedImageInfo {
                ImageDetailView(imageInfo: imageInfo)
            }
        }
        .actionSheet(isPresented: $showingExportOptions) {
            ActionSheet(
                title: Text("Export Options"),
                buttons: [
                    .default(Text("Copy All URLs")) {
                        UIPasteboard.general.string = imageService.exportImageURLs()
                    },
                    .default(Text("Copy Detailed Info")) {
                        UIPasteboard.general.string = imageService.exportImageInfo()
                    },
                    .cancel()
                ]
            )
        }
        .actionSheet(isPresented: $showingDownloadOptions) {
            ActionSheet(
                title: Text("Download Options"),
                message: Text("This will download all \(imageService.allImages.count) images to your device storage."),
                buttons: [
                    .default(Text("Download All Images")) {
                        downloader.downloadAllImages { successCount, errors in
                            print("Downloaded \(successCount) images")
                            for error in errors {
                                print("Error: \(error)")
                            }
                        }
                    },
                    .destructive(Text("Clear Downloaded Images")) {
                        downloader.clearDownloadedImages()
                    },
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search images...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct LoadingView: View {
    let progress: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(progress)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DownloadProgressView: View {
    @ObservedObject var downloader: AdaloImageDownloader
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Downloading Images")
                .font(.title2)
                .bold()
            
            ProgressView(value: downloader.downloadProgress.isNaN ? 0 : downloader.downloadProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(maxWidth: 200)
            
            Text(downloader.downloadStatus)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("\(Int((downloader.downloadProgress.isNaN ? 0 : downloader.downloadProgress) * 100))% Complete")
                .font(.headline)
                .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct EmptyStateView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Images Found")
                .font(.title2)
                .bold()
            
            Text("Tap the button below to fetch all images from your Adalo collections")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Fetch Images") {
                onRefresh()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ImageGridView: View {
    let images: [AdaloImageService.AdaloImageInfo]
    let onImageTap: (AdaloImageService.AdaloImageInfo) -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(images.indices, id: \.self) { index in
                    let image = images[index]
                    
                    AsyncImage(url: URL(string: image.url)) { imagePhase in
                        switch imagePhase {
                        case .success(let uiImage):
                            uiImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    VStack {
                                        Spacer()
                                        HStack {
                                            SourceBadge(source: image.source)
                                            Spacer()
                                        }
                                    }
                                    .padding(4)
                                )
                        case .failure(_):
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                )
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .onTapGesture {
                        onImageTap(image)
                    }
                }
            }
            .padding()
        }
    }
}

struct SourceBadge: View {
    let source: String
    
    var body: some View {
        Text(source.uppercased())
            .font(.system(size: 8))
            .bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForSource(source))
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private func colorForSource(_ source: String) -> Color {
        switch source {
        case "user": return .blue
        case "event": return .green
        case "place": return .orange
        default: return .gray
        }
    }
}

struct ImageDetailView: View {
    let imageInfo: AdaloImageService.AdaloImageInfo
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Image
                    AsyncImage(url: URL(string: imageInfo.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(ProgressView())
                    }
                    .cornerRadius(12)
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(title: "Source", value: imageInfo.source.capitalized)
                        DetailRow(title: "Record ID", value: "\(imageInfo.recordId)")
                        DetailRow(title: "Filename", value: imageInfo.filename ?? "N/A")
                        DetailRow(title: "Size", value: imageInfo.size?.formatted() ?? "N/A")
                        DetailRow(title: "Dimensions", value: "\(imageInfo.width ?? 0) × \(imageInfo.height ?? 0)")
                        DetailRow(title: "BlurHash", value: imageInfo.blurHash ?? "N/A")
                        
                        // URL (scrollable)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("URL")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(imageInfo.url)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            Button("Copy URL") {
                                UIPasteboard.general.string = imageInfo.url
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

#Preview {
    AdaloTestView()
} 