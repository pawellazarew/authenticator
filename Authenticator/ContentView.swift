import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TokenData.indexNumber, ascending: true)], animation: .default)
    private var fetchedTokens: FetchedResults<TokenData>

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemaining: Int = 30 - (Int(Date().timeIntervalSince1970) % 30)
    @State private var codes: [String] = Array(repeating: String.zeros, count: 50)
    @State private var animationTrigger: Bool = false

    @State private var isSheetPresented: Bool = false
    @State private var isFileImporterPresented: Bool = false

    @State private var editMode: EditMode = .inactive
    @State private var selectedTokens = Set<TokenData>()
    @State private var indexSetOnDelete: IndexSet = .init()
    @State private var isDeletionAlertPresented: Bool = false

    init() {
        UITableView.appearance().sectionFooterHeight = 0
        UITextField.appearance().clearButtonMode = .always
    }

    var body: some View {
        NavigationView {
            List(selection: $selectedTokens) {
                ForEach(0 ..< fetchedTokens.count, id: \.self) { index in
                    let item = fetchedTokens[index]
                    Section {
                        CodeCardView(token: token(of: item), totp: $codes[index], timeRemaining: $timeRemaining)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = codes[index]
                                } label: {
                                    Label("Copy Code", systemImage: "doc.on.doc")
                                }
                                Button {
                                    tokenIndex = index
                                    presentingSheet = .cardDetailView
                                    isSheetPresented = true
                                } label: {
                                    Label("View Detail", systemImage: "text.justifyleft")
                                }
                                Button {
                                    tokenIndex = index
                                    presentingSheet = .cardEditing
                                    isSheetPresented = true
                                } label: {
                                    Label("Edit Account", systemImage: "square.and.pencil")
                                }
                                Button {
                                    tokenIndex = index
                                    selectedTokens.removeAll()
                                    indexSetOnDelete.removeAll()
                                    isDeletionAlertPresented = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .onMove(perform: move(from:to:))
                .onDelete(perform: deleteItems)
            }
            .animation(.default, value: animationTrigger)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                generateCodes()
                clearTemporaryDirectory()
            }
            .onReceive(timer) { _ in
                timeRemaining = 30 - (Int(Date().timeIntervalSince1970) % 30)
                if timeRemaining == 30 || codes.first == String.zeros {
                    generateCodes()
                }
            }
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.text, .image], allowsMultipleSelection: false) { result in
                switch result {
                case let .failure(error):
                    logger.debug(".fileImporter() failure: \(error.localizedDescription)")
                case let .success(urls):
                    guard let pickedUrl: URL = urls.first else { return }
                    guard pickedUrl.startAccessingSecurityScopedResource() else { return }
                    let cachePathComponent = Date.currentDateText + pickedUrl.lastPathComponent
                    let cacheUrl: URL = .tmpDirectoryUrl.appendingPathComponent(cachePathComponent)
                    try? FileManager.default.copyItem(at: pickedUrl, to: cacheUrl)
                    pickedUrl.stopAccessingSecurityScopedResource()
                    handlePickedFile(url: cacheUrl)
                }
            }
            .alert(isPresented: $isDeletionAlertPresented) {
                deletionAlert
            }
            .navigationTitle("Authenticator")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if editMode == .active {
                        Button {
                            editMode = .inactive
                            selectedTokens.removeAll()
                            indexSetOnDelete.removeAll()
                        } label: {
                            Text("Done")
                        }
                    } else {
                        Menu {
                            Button {
                                selectedTokens.removeAll()
                                indexSetOnDelete.removeAll()
                                editMode = .active
                            } label: {
                                Label("Edit", systemImage: "list.bullet")
                            }
                            Button {
                                presentingSheet = .moreExport
                                isSheetPresented = true
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            Button {
                                presentingSheet = .moreAbout
                                isSheetPresented = true
                            } label: {
                                Label("About", systemImage: "info.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26)
                                .padding(.trailing, 8)
                                .contentShape(Rectangle())
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if editMode == .active {
                        Button {
                            if !selectedTokens.isEmpty {
                                isDeletionAlertPresented = true
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                    } else {
                        #if !targetEnvironment(macCatalyst)
                            Button {
                                presentingSheet = .addByScanning
                                isSheetPresented = true
                            } label: {
                                Image(systemName: "qrcode.viewfinder")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24)
                                    .padding(.horizontal, 2)
                                    .contentShape(Rectangle())
                            }
                        #endif
                        Menu {
                            #if !targetEnvironment(macCatalyst)
                                Button {
                                    presentingSheet = .addByScanning
                                    isSheetPresented = true
                                } label: {
                                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                                }
                            #endif
                            Button {
                                presentingSheet = .addByQRCodeImage
                                isSheetPresented = true
                            } label: {
                                Label("Import from Photos", systemImage: "photo")
                            }
                            Button {
                                isFileImporterPresented = true
                            } label: {
                                #if targetEnvironment(macCatalyst)
                                    Label("Import from Finder", systemImage: "text.below.photo")
                                #else
                                    Label("Import from Files", systemImage: "doc.badge.plus")
                                #endif
                            }
                            Button {
                                presentingSheet = .addByManually
                                isSheetPresented = true
                            } label: {
                                Label("Enter Manually", systemImage: "text.cursor")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25)
                                .padding(.leading, 8)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
            .sheet(isPresented: $isSheetPresented) {
                switch presentingSheet {
                case .moreExport:
                    ExportView(isPresented: $isSheetPresented, tokens: tokensToExport)
                case .moreAbout:
                    AboutView(isPresented: $isSheetPresented)
                case .addByScanning:
                    Scanner(isPresented: $isSheetPresented, codeTypes: [.qr], completion: handleScanning(result:))
                case .addByQRCodeImage:
                    PhotoPicker(completion: handlePickedImage(uri:))
                case .addByManually:
                    ManualEntryView(isPresented: $isSheetPresented, completion: addItem(_:))
                case .cardDetailView:
                    TokenDetailView(isPresented: $isSheetPresented, token: token(of: fetchedTokens[tokenIndex]))
                case .cardEditing:
                    EditAccountView(isPresented: $isSheetPresented, token: token(of: fetchedTokens[tokenIndex]), tokenIndex: tokenIndex) { index, issuer, account in
                        handleAccountEditing(index: index, issuer: issuer, account: account)
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Modification

    private func addItem(_ token: Token) {
        let newTokenData = TokenData(context: viewContext)
        newTokenData.id = token.id
        newTokenData.uri = token.uri
        newTokenData.displayIssuer = token.displayIssuer
        newTokenData.displayAccountName = token.displayAccountName
        let lastIndexNumber: Int64 = fetchedTokens.last?.indexNumber ?? Int64(fetchedTokens.count)
        newTokenData.indexNumber = lastIndexNumber + 1
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            logger.debug("\(nsError)")
        }
        generateCodes()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var idArray: [String] = fetchedTokens.map { $0.id ?? Token().id }
        idArray.move(fromOffsets: source, toOffset: destination)
        for number in 0 ..< fetchedTokens.count {
            let item = fetchedTokens[number]
            guard let index = idArray.firstIndex(where: { $0 == item.id }), Int64(index) != item.indexNumber else { continue }
            fetchedTokens[number].indexNumber = Int64(index)
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            logger.debug("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        selectedTokens.removeAll()
        indexSetOnDelete = offsets
        isDeletionAlertPresented = true
    }

    private func cancelDeletion() {
        indexSetOnDelete.removeAll()
        selectedTokens.removeAll()
        isDeletionAlertPresented = false
    }

    private func performDeletion() {
        if !selectedTokens.isEmpty {
            _ = selectedTokens.map { oneSelection in
                _ = fetchedTokens.filter { $0.id == oneSelection.id }.map(viewContext.delete)
            }
        } else if !indexSetOnDelete.isEmpty {
            _ = indexSetOnDelete.map { fetchedTokens[$0] }.map(viewContext.delete)
        } else {
            viewContext.delete(fetchedTokens[tokenIndex])
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            logger.debug("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        indexSetOnDelete.removeAll()
        selectedTokens.removeAll()
        isDeletionAlertPresented = false
        generateCodes()
    }

    private var deletionAlert: Alert {
        Alert(
            title: Text("Delete Account?"),
            message: Text("Account Deletion Warning"),
            primaryButton: .cancel(cancelDeletion),
            secondaryButton: .destructive(Text("Delete"), action: performDeletion)
        )
    }

    // MARK: - Account Adding

    private func handleScanning(result: Result<String, ScannerView.ScanError>) {
        isSheetPresented = false
        switch result {
        case let .success(code):
            let uri: String = code.trimmed
            guard !uri.isEmpty else { return }
            guard let newToken: Token = Token(uri: uri) else { return }
            addItem(newToken)
        case let .failure(error):
            logger.debug("\(error.localizedDescription)")
        }
    }

    private func handlePickedImage(uri: String) {
        let qrCodeUri = uri.trimmed
        guard !qrCodeUri.isEmpty, let newToken = Token(uri: qrCodeUri) else { return }
        addItem(newToken)
    }

    private func handlePickedFile(url: URL) {
        guard let content: String = url.readText else { return }
        content.components(separatedBy: .newlines).forEach {
            guard let newToken = Token(uri: $0.trimmed) else { return }
            addItem(newToken)
        }
    }

    // MARK: - Methods

    private func token(of tokenData: TokenData) -> Token {
        guard let id: String = tokenData.id,
              let uri: String = tokenData.uri,
              let displayIssuer: String = tokenData.displayIssuer,
              let displayAccountName: String = tokenData.displayAccountName
        else { return Token() }
        return Token(id: id, uri: uri, displayIssuer: displayIssuer, displayAccountName: displayAccountName) ?? Token()
    }

    private func generateCodes() {
        let placeholder: [String] = Array(repeating: String.zeros, count: 30)
        guard !fetchedTokens.isEmpty else {
            codes = placeholder
            return
        }
        let generated: [String] = fetchedTokens.map { code(of: $0) }
        codes = generated + placeholder
        animationTrigger.toggle()
    }

    private func code(of tokenData: TokenData) -> String {
        guard 
            let uri: String = tokenData.uri,
            let token = Token(uri: uri),
            let code = OTPGenerator.totp(secret: token.secret, algorithm: token.algorithm, digits: token.digits, period: token.period)
        else { return String.zeros }
        return code
    }

    private func handleAccountEditing(index: Int, issuer: String, account: String) {
        let item: TokenData = fetchedTokens[index]
        if item.displayIssuer != issuer {
            fetchedTokens[index].displayIssuer = issuer
        }
        if item.displayAccountName != account {
            fetchedTokens[index].displayAccountName = account
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            logger.debug("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        isSheetPresented = false
    }

    private var tokensToExport: [Token] {
        fetchedTokens.map { token(of: $0) }
    }

    private func clearTemporaryDirectory() {
        try? FileManager.default.contentsOfDirectory(at: .tmpDirectoryUrl, includingPropertiesForKeys: nil).forEach {
            try? FileManager.default.removeItem(at: $0)
        }
    }
}

private var presentingSheet: SheetSet = .moreAbout
private var tokenIndex: Int = 0

private enum SheetSet {
    case moreExport
    case moreAbout
    case addByScanning
    case addByQRCodeImage
    case addByManually
    case cardDetailView
    case cardEditing
}
