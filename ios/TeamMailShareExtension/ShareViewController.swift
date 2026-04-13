// import receive_sharing_intent

// class ShareViewController: RSIShareViewController {
// }

import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {
    
    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        // Handle shared content
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            if let attachments = item.attachments {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier("public.url") {
                        attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { (url, error) in
                            if let shareURL = url as? URL {
                                // Store in App Group for main app to read
                                let userDefaults = UserDefaults(suiteName: "group.jambo.barua.app")
                                userDefaults?.set(shareURL.absoluteString, forKey: "sharedURL")
                                userDefaults?.synchronize()
                            }
                        }
                    }
                }
            }
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}