//
//  ContentView.swift
//  AppAttestTest
//
//  Created by Pushp Abrol on 12/21/23.
//

import SwiftUI
import DeviceCheck
import CryptoKit

struct ContentView: View {
    @StateObject var viewModel = AppAttestViewModel()
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    if UserDefaults.standard.string(forKey: "appAttestKeyId") == nil {
                        Button("Generate Attestation Key") {
                            viewModel.generateAttestationKey()
                        }.buttonStyle(PrimaryButtonStyle())
                            .disabled(viewModel.isLoading)
                        
                        if viewModel.keyIdentifier != nil {
                            keyIdentifierSection
                            if let attestationObjectString = viewModel.attestationObjectString {
                                Section(header: Text("Attestation Object")) {
                                                Text(attestationObjectString)
                                                    .padding()
                                                    .border(Color.gray, width: 1)
                                                    .cornerRadius(8)
                                            }

                            }
                        }
                    }
                    else {
                        assertionSection
                    }
                    

                }
                .padding()
                .navigationTitle("App Attest Example")
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(title: Text("Status"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private var keyIdentifierSection: some View {
        Section(header: Text("Key Identifier")) {
            Text(viewModel.keyIdentifier ?? "Not Available")
                .padding()
                .border(Color.gray, width: 1)
                .cornerRadius(8)

            if viewModel.attestationObjectString == nil {
                if viewModel.isAttestationChallengeReceived {
                    Button("Create Attestation", action: viewModel.createAttestationObject)
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("Fetching attestation challenge...")
                        .onAppear(perform: viewModel.requestAttestationChallenge)
                }
            }
        }
    }
    private var assertionSection: some View {
        Section(header: Text("Key Identifier")) {
            Text(UserDefaults.standard.string(forKey: "appAttestKeyId") ?? "Not Available")
                .padding()
                .border(Color.gray, width: 1)
                .cornerRadius(8)
            if viewModel.isAssertionChallengeReceived {
                            Button("Create & Send Assertion to Server"){
                                viewModel.createAndSendAssertion()
                            }.buttonStyle(PrimaryButtonStyle())
                        } else {
                            // UI indicating that the challenge is being fetched
                            Text("Fetching assertion challenge...")
                                .onAppear(perform: viewModel.requestAssertionChallenge)
                        }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

class AppAttestViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var keyIdentifier: String? // Store the key identifier
    @Published var attestationChallenge: String? // Store the attestation challenge
    @Published var attestationObjectString: String?
    @Published var isAttestationChallengeReceived = false
    @Published var assertionChallenge: String? // Store the attestation challenge
    @Published var isAssertionChallengeReceived = false

    
    init(){
        keyIdentifier = UserDefaults.standard.string(forKey: "appAttestKeyId");
    }
   
    func generateAttestationKey() {
        isLoading = true
        DCAppAttestService.shared.generateKey { [weak self] (result, error) in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.alertMessage = error.localizedDescription
                    self?.showAlert = true
                    return
                }

                if let keyId = result {
                    self?.keyIdentifier = keyId // Update the key identifier
                    print(keyId);
                }
            }
        }
    }
    
    func requestAttestationChallenge() {
        guard let url = URL(string: "https://attestation-verification.vercel.app/generate-attestion-challenge") else { return }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Check if an error occurred
            DispatchQueue.main.async {
            if let error = error {
                print("Error making request: \(error.localizedDescription)")
                return
            }
                // Check if data was received
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                // Attempt to decode the JSON response
                do {
                    // Define a Codable struct that matches the JSON structure
                    struct Response: Codable {
                        var attestationChallenge: String
                        
                    }
                    
                    // Decode the JSON data
                    let jsonResponse = try JSONDecoder().decode(Response.self, from: data)
                    self.attestationChallenge = jsonResponse.attestationChallenge
                    self.isAttestationChallengeReceived = true
                    // Use the decoded data
                } catch {
                    print("Error decoding JSON: \(error.localizedDescription)")
                }
            }
        }

        task.resume()
    }
    
    func requestAssertionChallenge() {
        guard let url = URL(string: "https://attestation-verification.vercel.app/generate-assertion-challenge") else { return }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
            // Check if an error occurred
            if let error = error {
                print("Error making request: \(error.localizedDescription)")
                return
            }
           
                // Check if data was received
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                // Attempt to decode the JSON response
                do {
                    // Define a Codable struct that matches the JSON structure
                    struct Response: Codable {
                        var assertionChallenge: String
                        
                    }
                    
                    // Decode the JSON data
                    let jsonResponse = try JSONDecoder().decode(Response.self, from: data)
                    self.assertionChallenge = jsonResponse.assertionChallenge
                    self.isAssertionChallengeReceived = true
                    // Use the decoded data
                } catch {
                    print("Error decoding JSON: \(error.localizedDescription)")
                }
            }
        }

        task.resume()
    }
    
    func createAttestationObject() {
            guard let keyIdentifier = keyIdentifier else {
                alertMessage = "Key identifier is not available."
                showAlert = true
                return
            }

            // Generate a client data hash (example: hash of a simple string)
        let clientData = self.attestationChallenge!.data(using: .utf8)!
            let clientDataHash = SHA256.hash(data: clientData)
                let clientDataHashData = Data(clientDataHash)

            isLoading = true
            DCAppAttestService.shared.attestKey(keyIdentifier, clientDataHash: clientDataHashData) { [weak self] (attestationObject, error) in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.alertMessage = error.localizedDescription
                        self?.showAlert = true
                        return
                    }

                    if let attestationObject = attestationObject {
                        // Handle the attestation object (e.g., send to your server)
                        // For demonstration, we'll just show a success message
                        self?.attestationObjectString = attestationObject.base64EncodedString()
                        print(attestationObject.base64EncodedString());
                        self?.alertMessage = "Attestation object created successfully."
                        self?.showAlert = true
                        self?.sendAttestationToServer(attestationObject: attestationObject, keyId: keyIdentifier)
                    }
                }
            }
        }
    func saveKeyId() {
            if let keyId = keyIdentifier {
                UserDefaults.standard.set(keyId, forKey: "appAttestKeyId")
            }
        }
    
    func sendAttestationToServer(attestationObject: Data, keyId: String) {
            // Prepare URL and URLRequest
            guard let url = URL(string: "https://attestation-verification.vercel.app/verify-attestation") else {
                alertMessage = "Invalid server URL."
                showAlert = true
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Prepare the JSON body
            let body: [String: Any] = [
                "attestationObject": attestationObject.base64EncodedString(),
                "keyId": keyId
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                alertMessage = "Failed to encode request body."
                showAlert = true
                return
            }
            
            // Perform the network request
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.alertMessage = "Network request failed: \(error.localizedDescription)"
                        self?.showAlert = true
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        self?.alertMessage = "Attestation verified successfully by server.";
                        self?.saveKeyId()
                    } else {
                        self?.alertMessage = "Server failed to verify attestation."
                    }
                    self?.showAlert = true
                }
            }.resume()
        }
}




#Preview {
    ContentView()
}

struct CopyableTextView: UIViewRepresentable {
    var text: String
    var isEditable: Bool = false

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.text = text
        textView.isEditable = isEditable
        textView.dataDetectorTypes = [] // Disable link, phone number, etc. detection
        textView.isScrollEnabled = false // Disable scrolling
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.backgroundColor = nil // Set background color to nil for transparent background
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
}

extension AppAttestViewModel {
    func createAndSendAssertion() {
        guard let keyIdentifier = keyIdentifier else {
            alertMessage = "Key identifier is not available."
            showAlert = true
            return
        }
        let challenge =  self.assertionChallenge!
        let assertionContent = ["userId": "User123", "client_id": "1234", "challenge" : challenge] as [String: Any]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: assertionContent) else {
            alertMessage = "Failed to encode assertion content."
            showAlert = true
            return
        }
        print(jsonData);
        signAndSendAssertion(jsonData: jsonData, keyId: keyIdentifier)
    }

    func signAndSendAssertion(jsonData: Data, keyId: String) {
        // Create a client data hash
        let clientDataHash = SHA256.hash(data: jsonData)
        let clientDataHashData = Data(clientDataHash)

        DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHashData) { [weak self] (assertion, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.alertMessage = "Error generating assertion: \(error.localizedDescription)"
                    self.showAlert = true
                    return
                }

                if let assertion = assertion {
                    // Send the assertion to your server
                    self.sendAssertionToServer(clientData: jsonData,assertion: assertion, keyId: keyId)
                }
            }
        }
    }

    private func sendAssertionToServer(clientData: Data, assertion: Data, keyId: String) {
        guard let url = URL(string: "https://attestation-verification.vercel.app/verify-assertion") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "clientData": clientData.base64EncodedString(),
            "assertion": assertion.base64EncodedString(),
            "keyId": keyId
        ]
        print(body);
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Failed to encode request body.")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Network request failed: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("Assertion successfully sent to server.")
                    print(httpResponse.statusCode)
                    self.alertMessage = "Assertion verification successful!"
                    self.showAlert = true
                } else {
                    print("Server failed to process the assertion.")
                    self.alertMessage = "Assertion verification failed"
                    self.showAlert = true
                }
            }
        }.resume()
    }

}

