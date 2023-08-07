import MessageUI
import SwiftUI
import Logger

struct ReportABugMailView: UIViewControllerRepresentable {
    
    @Environment(\.presentationMode) var presentation
    @Binding var result: Result<MFMailComposeResult, Error>?
    
    typealias UIViewControllerType = MFMailComposeViewController
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?
        
        init(
            presentation: Binding<PresentationMode>,
            result: Binding<Result<MFMailComposeResult, Error>?>
        ) {
            _presentation = presentation
            _result = result
        }
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            self.result = .success(result)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(presentation: presentation, result: $result)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailViewController = MFMailComposeViewController()
        mailViewController.mailComposeDelegate = context.coordinator
        mailViewController.setToRecipients(["support@planetary.social"])
        mailViewController.setSubject("Reporting a bug in Planetary")
        mailViewController.setMessageBody(
            "Hello, \n\n I have found a bug in Planetary and would like to provide feedback",
            isHTML: false
        )
        Task {
            do {
                /*
                mailViewController.addAttachmentData(
                    try Data(contentsOf: try await LogHelper.zipLogs()),
                    mimeType: "application/zip",
                    fileName: "diagnostics.zip"
                )
                 */
            } catch {
                Log.error("failed to zip logs for ReportABugMailView")
            }
        }
        return mailViewController
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
    }
}
