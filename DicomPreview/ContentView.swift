import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.viewfinder")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("DICOM File QuickLook Preview")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Warning Box
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text("WARNING: This preview tool is not intended for clinical use!")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(width: 500)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.8))
            )
            
            // Features Box
            VStack(alignment: .leading, spacing: 10) {
                Text("This app provides a QuickLook extension to preview DICOM files.")
                    .font(.headline)
                
                Text("Features:")
                    .font(.headline)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 5) {
                    FeatureRow(icon: "table", text: "View DICOM attributes in a table format")
                    FeatureRow(icon: "tag", text: "See all DICOM tags with their values")
                    FeatureRow(icon: "bolt", text: "Fast Rust-based DICOM parsing")
                    FeatureRow(icon: "magnifyingglass", text: "Preview files in Finder with QuickLook")
                }
                
                Text("To use: Press spacebar when selecting a DICOM file in Finder")
                    .font(.headline)
                    .padding(.top, 10)
            }
            .padding()
            .frame(width: 500)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.darkGray))
            )
        }
        .padding()
        .frame(minWidth: 700, minHeight: 600)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
