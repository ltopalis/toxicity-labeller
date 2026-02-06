import SwiftUI
import CoreXLSX
import UniformTypeIdentifiers

struct ToxicityDataRow: Codable {
    let text_id: String
    let text: String
    let toxicity: String
    let target_type: String
    let bias_type: String
}

struct ServerStats: Codable {
    let gr: Int
    let ngr: Int
    let de: Int
    let nde: Int
}

struct ContentView: View {
    @State private var selectedLanguage = "gr"
    @State private var statsLang = "all"
    @State private var statusMessage = "Επιλέξτε αρχείο για επεξεργασία"
    
    // Αποθηκεύουμε το αντικείμενο των στατιστικών εδώ
    @State private var lastFetchedStats: ServerStats? = nil
    
    @State private var totalCount: String = "-"
    @State private var withValueCount: String = "-"
    @State private var withoutValueCount: String = "-"
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Toxicity Evaluator Admin")
                .font(.largeTitle)
                .bold()
            
            VStack(spacing: 20) {
                HStack(spacing: 50) {
                    StatCard(title: "Σύνολο", value: totalCount, valueColor: .blue)
                    StatCard(title: "Με τιμή", value: withValueCount, valueColor: .green)
                    StatCard(title: "Χωρίς τιμή", value: withoutValueCount, valueColor: .orange)
                }
                
                Picker("", selection: $statsLang) {
                    Text("Όλα").tag("all")
                    Text("Ελληνικά").tag("gr")
                    Text("Γερμανικά").tag("de")
                }
                .pickerStyle(.segmented)
                .frame(width: 250) // Λίγο μεγαλύτερο για να χωράνε τα κείμενα
                .onChange(of: statsLang) { newValue in
                    updateDisplayStats(with: newValue)
                }
            }

            Divider()

            VStack(spacing: 15) {
                Picker("Γλώσσα Ανεβάσματος:", selection: $selectedLanguage) {
                    Text("Ελληνικά").tag("gr")
                    Text("Γερμανικά").tag("de")
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                Button(action: selectAndProcessExcel) {
                    Label("Επιλογή & Αποστολή Excel", systemImage: "arrow.up.doc.fill")
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
            }

            Text(statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            Button(action: downloadExcel) {
                Label("Αποθήκευση", systemImage: "arrow.down.doc.fill")
                    .padding(8)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(minWidth: 600, minHeight: 450)
        .padding()
        .onAppear {
            fetchStats()
        }
    }
    
    // MARK: - Logic functions
    
    func updateDisplayStats(with lang: String) {
        guard let stats = lastFetchedStats else { return }
        
        DispatchQueue.main.async {
            switch lang {
            case "gr":
                self.totalCount = "\(stats.gr + stats.ngr)"
                self.withValueCount = "\(stats.gr)"
                self.withoutValueCount = "\(stats.ngr)"
            case "de":
                self.totalCount = "\(stats.de + stats.nde)"
                self.withValueCount = "\(stats.de)"
                self.withoutValueCount = "\(stats.nde)"
            default: // "all"
                self.totalCount = "\(stats.de + stats.nde + stats.gr + stats.ngr)"
                self.withValueCount = "\(stats.de + stats.gr)"
                self.withoutValueCount = "\(stats.nde + stats.ngr)"
            }
        }
    }

    // MARK: - API Calls
    
    func fetchStats() {
        guard let url = URL(string: "https://toxicity-backend.onrender.com/getStats") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let stats = try? JSONDecoder().decode(ServerStats.self, from: data) {
                // Αποθήκευση των δεδομένων
                self.lastFetchedStats = stats
                // Ενημέρωση των labels βάσει του επιλεγμένου φίλτρου
                updateDisplayStats(with: self.statsLang)
            }
        }.resume()
    }
    
    // ... (Οι υπόλοιπες συναρτήσεις uploadToServer & selectAndProcessExcel παραμένουν ίδιες)
    
    func uploadToServer(jsonData: Data, count: Int) {
        guard let url = URL(string: "https://toxicity-backend.onrender.com/upload-data") else { return }
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        updateStatus("Αποστολή...")
        URLSession(configuration: config).dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                updateStatus("Επιτυχία! \(count) γραμμές.")
                fetchStats() 
            } else {
                updateStatus("Σφάλμα Server")
            }
        }.resume()
    }

    func selectAndProcessExcel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!].compactMap { $0 }
        if panel.runModal() == .OK {
            guard let url = panel.url else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            updateStatus("Επεξεργασία...")
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let file = XLSXFile(filepath: url.path) else { return }
                    var rowsToUpload: [ToxicityDataRow] = []
                    for path in try file.parseWorksheetPaths() {
                        let worksheet = try file.parseWorksheet(at: path)
                        if let sharedStrings = try file.parseSharedStrings() {
                            let columnData = worksheet.data?.rows.dropFirst()
                            columnData?.forEach { row in
                                func safeValue(at index: Int) -> String {
                                    guard row.cells.count > index else { return "" }
                                    return row.cells[index].stringValue(sharedStrings) ?? ""
                                }
                                let tid = safeValue(at: 0)
                                if !tid.isEmpty {
                                    rowsToUpload.append(ToxicityDataRow(
                                        text_id: tid, text: safeValue(at: 1),
                                         toxicity: safeValue(at: 2),
                                        target_type: safeValue(at: 4), bias_type: safeValue(at: 3)
                                    ))
                                }
                            }
                        }
                    }
                    let data = try JSONEncoder().encode(rowsToUpload)
                    self.uploadToServer(jsonData: data, count: rowsToUpload.count)
                } catch { updateStatus("Σφάλμα Excel") }
            }
        }
    }

    func updateStatus(_ message: String) {
        DispatchQueue.main.async { self.statusMessage = message }
    }
    
    func downloadExcel() {
        let url = URL(string: "https://toxicity-backend.onrender.com/getAllData")!
            
            updateStatus("Προετοιμασία Excel...")
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                // 1. Έλεγχος αν υπάρχουν δεδομένα
                guard let data = data, error == nil else {
                    updateStatus("Σφάλμα σύνδεσης.")
                    return
                }
                
                // 2. Έλεγχος αν ο server έστειλε σφάλμα (π.χ. 500) αντί για αρχείο
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let serverError = String(data: data, encoding: .utf8) ?? "Unknown Error"
                    print("Server Error: \(serverError)")
                    updateStatus("Σφάλμα Server: \(httpResponse.statusCode)")
                    return
                }

                // 3. Αποθήκευση
                DispatchQueue.main.async {
                    let fileManager = FileManager.default
                    if let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                        let fileName = "Toxicity_Export_\(Int(Date().timeIntervalSince1970)).xlsx"
                        let destinationURL = downloadsURL.appendingPathComponent(fileName)
                        
                        do {
                            try data.write(to: destinationURL)
                            updateStatus("Το Excel αποθηκεύτηκε!")
                            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                        } catch {
                            updateStatus("Σφάλμα αποθήκευσης.")
                        }
                    }
                }
            }.resume()
    }
}

struct StatCard: View {

    let title: String

    let value: String

    let valueColor: SwiftUI.Color

    

    var body: some View {

        VStack {

            Text(value)

                .font(.system(size: 24, weight: .bold, design: .rounded))

                .foregroundColor(valueColor)

            Text(title)

                .font(.subheadline)

        }

    }

}



#Preview {
    ContentView()
}
