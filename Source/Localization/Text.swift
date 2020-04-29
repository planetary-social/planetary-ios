// provide the types of any new Localizable enums
// in order to automatically export their strings to the localization files
extension Text {
    static var localizableTypes: [Localizable.Type] {
        return [Text.self,
                Text.Blocking.self,
                Text.ImagePicker.self,
                Text.NewPost.self,
                Text.Offboarding.self,
                Text.Onboarding.self,
                Text.Onboarding.StepTitle.self,
                Text.ManagePubs.self,
                Text.Preview.self,
                Text.Push.self,
                Text.Reporting.self,
                Text.Debug.self,
                Text.Error.self]
    }
}

// MARK:- Generic

enum Text: String, Localizable, CaseIterable {

    case planetary = "Planetary"

    case error = "Oops"
    case cancel = "Cancel"
    case skip = "Skip"
    case ok = "OK"
    case next = "Next"
    case done = "Done"
    case save = "Save"
    case yes = "Yes"
    case no = "No"
    case tryAgain = "Try Again"
    case loading = "Loading..."

    case today = "Today"
    case yesterday = "Yesterday"
    case recently = "Recently"
    case future = "In the future"
    case daysAgo = "{{ days }} days ago"
    case atDayTime = "{{ day }} at {{ time }}"

    case yourProfile = "Your Profile"
    case helpAndSupport = "Help and Support"
    case reportBug = "Report a Bug"
    case settings = "Settings"
    case userDirectory = "User Directory"
    case showMeInDirectory = "Show me in the directory"
    case showMeInUserDirectory = "Show me in the user directory"
    case hideMeFromUserDirectory = "Hide me from the user directory"
    case analyticsAndCrash = "Analytics & Crash Reports"
    case usageData = "Usage Data"
    case userDirectoryMessage = "Being in the user directory means that people can find you if they already know your name, short code or phone number."

    case sendAnalytics = "Send analytics to Planetary"
    case dontSendAnalytics = "Don't send analytics at all"
    case analyticsMessage = "We would like to capture anonymized data about your use of the app - and crash reports when something goes wrong - so we can make the application better."
    
    case loadingUpdates = "Planetary is searching for updates\non the peer to peer decentralized web."

    case post = "Post"
    case newPost = "New Post"
    case deletePost = "Delete this post"
    case editPost = "Edit this post"
    case confirmDeletePost = "Are you sure you want to delete this post?"

    case postReply = "Post Reply"
    case postAReply = "Post a reply"
    case createProfile = "Create Profile"
    case editProfile = "Edit Profile"
    case thisIsYou = "This is you!"
    case name = "Name"
    case bio = "Bio"
    case seeMore = "See more"

    case block = "Block"
    case blocked = "Blocked"

    case deleteSecretAndIdentity = "Delete this secret and identity"

    case follow = "Follow"
    case following = "Following"
    case followedBy = "Followed By"
    case isFollowingYou = "is currently following you"
    case followedByCount = "Followed by {{ count }} in your network"
    case followingCount = "Following {{ count }} in your network"
    case followedByShortCount = "{{ count }} Followers"
    case followingShortCount = "Following {{ count }}"

    case unfollow = "Stop following"

    case identifierCopied = "Identifier copied to clipboard"
    
    case copyMessageIdentifier = "Copy Message Identifier"
    
    case copyPublicIdentifier = "Copy Profile Identifier"
    case shareThisProfile = "Share This Profile"

    case addFriend = "Add friend"
    case removeFriend = "Remove from friends"

    case blockUser = "Block this user"
    case unblockUser = "Unblock this user"

    case reportPost = "Report this post"
    case reportUser = "Report this user"

    case noReplies = "No replies"
    case oneReply = "1 reply"
    case oneReplyFrom = "One reply from "
    case repliesFrom = "Replies from "
    case oneOther = "1 other"
    case replyCount = "{{ count }} replies"
    case andCountOthers = " and {{ count }} others"
    case countOthers = "{{ count }} others"
    case andOneOther = " and 1 other"

    case countOnlinePeers = "{{ count }} ONLINE PEERS"
    case countLocalPeers = "{{ count }} LOCAL PEERS"

    case channels = "Hashtags"
    case select = "Select"
    case home = "Home"
    case explore = "Explore"
    case messages = "Messages"
    case notifications = "Notifications"
    case thread = "Thread"

    case share = "Share"
    case bookmark = "Bookmark"
    case like = "Like"

    case debug = "Debug"
    
    case redeemInvitation = "Redeem an invitation"
    case pasteAddress = "Token"
}

// MARK:- ImagePicker

extension Text {

    enum ImagePicker: String, Localizable, CaseIterable {
        case camera = "Camera"
        case cameraNotAvailable = "Camera is not available on this device"
        case openSettingsMessage = "You can allow camera permissions by opening the Settings app."
        case permissionsRequired = "Permissions required for {{ title }}"
        case photoLibrary = "Photo Library"
        case selectFrom = "Select from Photo Library"
        case takePhoto = "Take photo with Camera"
    }
}

// MARK:- New post

extension Text {

    enum NewPost: String, Localizable, CaseIterable {
        case confirmRemove = "Remove this image from the post?  You can always add it back again."
        case remove = "Remove"
    }
}

// MARK:- Offboarding

extension Text {

    enum Offboarding: String, Localizable, CaseIterable {
        case reset = "Reset"
        case resetApplicationAndIdentity = "Reset application and identity"
        case resetConfirmTitle = "Warning"
        case resetConfirmMessage = "Are you sure want to reset your Planetary app? You will lose this identity and all related content. This cannot be undone."
        case resetConfirmAgainTitle = "Are you sure?"
        case resetConfirmAgainMessage = "Are you really sure you want to reset your Planetary app? You will lose this identity and all related content. This cannot be undone."
        case resetFooter = "Resetting the Planetary app will remove you from the user directory, unfollow everyone, and destroy your identity on your device. You will not be able to recover your identity, but you will be able to create a new one."
        case resetApiErrorTryAgain = "We weren't able to connect to the directory to remove you. Please try again."
        case resetBotErrorTryAgain = "Something unexpected happened but don't worry, we've made a note to fix it. Please try again."
    }
}

// MARK:- Onboarding

extension Text {

    enum Onboarding: String, Localizable, CaseIterable {
        enum StepTitle: String, Localizable, CaseIterable {
            case backup = "Okay, we've created your identity - would you like to back it up?"
            case benefits = "Planetary is a social network with a difference"
            case bio = "Why not say a little about yourself..."
            case birthday = "Before we start, when's your birthday?"
            case contacts = "You can connect your address book to see which of your friends are using Planetary"
            case directory = "People you might know"
            case done = "Well done, you made it through in one piece"
            case earlyAccess = "Gentle reminder: This is early access software"
            case join = "Creating your identity on Planetary..."
            case name = "Now, what would you like to be called?"
            case phone = "And what's your mobile number?"
            case phoneVerify = "Enter the code we just sent you to confirm..."
            case photo = "Okay that's the hard stuff - now let's get you a profile image"
            case photoConfirm = "Profile photo added"
            case resume = "Resuming set up of your identity on Planetary..."
            case start = "\nA new kind of social\nnetwork for creative,\nindependent people"

            static var namespace: String {
                return "OnboardingStepTitle"
            }
        }

        case getStartedButton = "Let's get started"

        case photoButtonAdd = "Add a photo"
        case photoButtonLater = "I'll do it later"

        case useRealName = "If you can, use your real name to help your friends find you."

        case phoneNumber = "Phone Number"
        case phoneNumberConfirmationMessage = "We use this to confirm your identity and for service alerts."
        case didntGetSMS = "Didn't get the SMS?"
        case reenter = "Re-enter"
        case resendSMS = "Resend SMS"
        case youEnteredNumber = "You entered the number {{ phone }}"
        case confirmNumber = "If that number is correct, tap 'Resend SMS'. If it is incorrect, tap 'Re-enter'."

        case ageLimit = "For legal reasons, you will need to be over sixteen to use Planetary."
        case chooseProfileImage = "Choose a\nprofile image"
        case changePhoto = "Change photo"
        case confirmPhoto = "Yes, that's good!"

        case startOver = "Start-Over"

        case contactsHint = "We one-way encrypt this data so we can never access it directly."
        case connect = "Connect away!"
        case notNow = "Not now"
        case contactsWIP = "Apologies, this feature is a work in progress. Tap 'OK' to see a list of recommended users to follow."
        case listMeTitle = "List me in the user directory"
        case listMeMessage = "This allows people to find you if they know your name or phone number"
        case thanksForTrying = "Thanks for trying Planetary and we look forward to seeing what you post."
        case doneOnboarding = "Phew! I'm done!"
        case earlyAccess = "This app is at an early stage. We've been focusing our time on the foundations, so there are gaps and rough bits in the UI. Bear with us!"
        case iUnderstand = "Yes, I understand"

        case somethingWentWrong = "Oh no! Something went wrong!"
        case errorRetryMessage = "This is not your fault, we messed something up. You can try again or start-over, and please come and tell one of us about it."
        case resumeRetryMessage = "This is not your fault, we messed something up. If some cases, it may mean your device cannot reach the network, and trying again later might help."

        case backupHint = "Planetary does not use passwords - you have a secret key that you need to keep safe. If you can, you should back it up. Note: this feature is still a work in progress."
        case backUp = "Yes, back up my identity"
        case bioHint = "Don't worry too much about what you say, you can change it later."

        case benefits = "We're part of an open ecosystem which respects your privacy, minimizes data collection and aims to reward content creators.\n\nAnd if you don't like our app, you can take your identity-and all your friends and content-to another service!\nFind out more"
        case findOutMore = "Find out more"
        case thatSoundsGreat = "That sounds great!"

        // note that ToS and PP are used to decorate the substrings in the statement
        // this means that the text must be the same otherwise the decoration will fail
        // check out `SplashOnboardingStep` to see how it is used
        case policyStatement = "By continuing, you confirm that you agree to our Terms of Service and Privacy Policy"
        case termsOfService = "Terms of Service"
        case privacyPolicy = "Privacy Policy"
    }
}

// MARK:- Manage Pubs

extension Text {

    enum ManagePubs: String, Localizable, CaseIterable {
        case header = "Pubs"
        case title = "Manage Pubs"
        case footer = "Pubs are relay servers that distribute messages through the scuttlebutt network. You are automatically connected to Planetary pubs, but you can connect to others if you'd prefer, or even run one yourself."
    }
}

// MARK:- Preview

extension Text {

    enum Preview: String, Localizable, CaseIterable {
        case title = "Advanced Settings"
        case footer = "New features that are being developed and tested, and haven't found a permanent home yet in the app."
    }
}

// MARK:- Push

extension Text {

    enum Push: String, Localizable, CaseIterable {
        case enabled = "Enabled"
        case title = "Push Notifications"
        case prompt = "Push notifications for Planetary are controlled in your device's Settings app.  Would you like to open Settings now?"
        case footer = "Show a system notification when you are mentioned, replied to, or followed.  The notification infrastructure is still in development, so you may not receive notifications consistently."
    }
}

// MARK:- Report

extension Text {

    enum Reporting: String, Localizable, CaseIterable {
        case abusive = "Abusive to me or someone else"
        case copyright = "Infringes on my copyright"
        case offensive = "Offensive or inappropriate"
        case other = "Some other reason"
        case whyAreYouReportingThisPost = "Why are you reporting this post?"
    }
}

// MARK:- Block

extension Text {

    enum Blocking: String, Localizable, CaseIterable {
        case alertTitle = "Are you sure you want to block {{ name }}? You will no longer see each others content or be able to contact each other."
        case buttonTitle = "Yes, block {{ name }}"
        case blockedUsers = "Blocked Users"
        case footer = "Blocked users cannot see your posts or contact you, and you will need to unblock them before you can see their posts or contact them. It may take some time to see users and content once they have been unblocked."
        case thisUser = "this user"
        case usersYouHaveBlocked = "Users that you have blocked"
    }
}

extension Text {
    
    enum Debug: String, Localizable, CaseIterable {
        case debugTitle = "Hacker Mode"
        case debugMenu = "Dangerous and powerful debug menu"
        case debugFooter = "This is where we let you shot yourself in the foot. Here is where you get at your private key, set new keys, see information about the network, pub's, and all sorts of things. Careful what you change in this menu, you can break things with these options."
    }
}

extension Text {
    
    enum Error: String, Localizable, CaseIterable {
        case login = "The peer to peer engine failed to start. Please try turning the app off and on again to see if that fixes it."
        case unexpected = "Something unexpected happened."
        case supportNotConfigured = "Support is not configured."
    }
}
