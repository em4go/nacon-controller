import Foundation

/// The commit the running bundle was built from.
///
/// It exists because the app once spent a round trip on a binary that predated the change being tested:
/// the commit and the tests were fine, the `.app` was old, and nothing on screen could say so.
///
/// A build made with `swift run` has no such key and says `dev`, which is the truth: the script did not
/// stamp it.
enum BuildStamp {
    static var commit: String {
        Bundle.main.object(forInfoDictionaryKey: "NaconBuildCommit") as? String ?? "dev"
    }

    static var text: String {
        AppText.format("Build %@", commit)
    }
}
