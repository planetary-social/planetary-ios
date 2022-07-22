// swiftlint:disable line_length identifier_name nesting

// provide the types of any new Localizable enums
// in order to automatically export their strings to the localization files
extension Text {
    static var localizableTypes: [Localizable.Type] {
        [
            Text.self,
            Text.Blocking.self,
            Text.ImagePicker.self,
            Text.NewPost.self,
            Text.Offboarding.self,
            Text.Onboarding.self,
            Text.Onboarding.StepTitle.self,
            Text.ManagePubs.self,
            Text.Preview.self,
            Text.FeedAlgorithm.self,
            Text.PublicWebHosting.self,
            Text.Push.self,
            Text.Reporting.self,
            Text.Debug.self,
            Text.Error.self,
            Text.Channel.self,
            Text.Post.self,
            Text.Report.self,
            Text.Notifications.self,
        ]
    }
}

// MARK: - Generic

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
    case minutesAbbreviated = "{{ numberOfMinutes }} mins"

    case yourProfile = "Your Profile"
    case helpAndSupport = "Help and Support"
    case reportBug = "Report a Bug"
    case settings = "Settings"
    case yourNetwork = "Your Network"
    case pubServers = "Pub Servers"
    case usersInYourNetwork = "Users in your network"
    case goToYourNetwork = "Go to Your Network"
    case emptyHomeFeedMessage = "And it is rather bare! Have you considered following a few users or topics?"
    case startedFollowing = "{{somebody}} started following"
    case stoppedFollowing = "{{somebody}} stopped following"
    case followStats = "Following {{numberOfFollows}} • Followed by {{numberOfFollowers}}"
    case showMeInDirectory = "Show me in the directory"
    case showMeInUserDirectory = "Show me in the user directory"
    case hideMeFromUserDirectory = "Hide me from the user directory"
    case analyticsAndCrash = "Analytics & Crash Reports"
    case usageData = "Usage Data"
    case userDirectoryMessage = "Being in the user directory means that people can find you if they already know your name, short code or phone number."

    case sendAnalytics = "Send analytics to Planetary"
    case dontSendAnalytics = "Don't send analytics at all"
    case analyticsMessage = "Allow us to collect data about your use of the app so we can make it better."
    
    case loadingUpdates = "Planetary is searching for updates\non the peer to peer decentralized web."

    case post = "Post"
    case preview = "Preview"
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
    case likesThis = "likes this"
    case dislikesThis = "dislikes this"

    case block = "Block"
    case blocked = "Blocked"

    case deleteSecretAndIdentity = "Delete this secret and identity"

    case follow = "Follow"
    case following = "Following"
    case followedBy = "Followed By"
    case isFollowingYou = "is currently following you"
    
    case followedByCount = "Followed by {{ count }}"
    case followingCount = "Following {{ count }}"
    case inYourNetwork = " in your network"
    
    case followedByShortCount = "{{ count }} Followers"

    case unfollow = "Stop following"

    case identifierCopied = "Identifier copied to clipboard"
    
    case copyMessageIdentifier = "Copy Message Identifier"
    
    case copyPublicIdentifier = "Copy Profile Identifier"
    case sharePublicIdentifier = "Share Public Identifier"
    
    case shareThisProfile = "Share This Profile"
    case shareThisMessage = "Share This Message"
    case shareThisProfileText = "Find {{ who }} on Planetary at {{ link }}"
    case shareThisMessageText = "{{ who }} posted: {{ what }} {{ link }}"

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

    case connectedPeers = "Connected Peers"
    case countOnlinePeers = "{{ count }} ONLINE PEERS"
    case countLocalPeers = "{{ count }} LOCAL PEERS"
    case lastSynced = "SYNCED: {{ when }}"
    case syncingMessages = "Syncing Messages..."
    case recentlyDownloaded = "Downloaded {{ postCount }} posts in the last {{ duration }} mins"
    case identityNotFound = "We don't know enough about this peer to show their profile."
    
    case channels = "Hashtags"
    case select = "Select"
    case home = "Home Feed"
    case explore = "Discover"
    case messages = "Messages"
    case notifications = "Notifications"
    case thread = "Thread"

    case share = "Share"
    case bookmark = "Bookmark"
    case like = "Like"

    case debug = "Debug"
    
    case join = "Join"
    case redeemInvitation = "Redeem an invitation"
    case pasteAddress = "Token"
    
    case refreshSingular = "{{ count }} unread post!"
    case refreshPlural = "{{ count }} unread posts!"

    case markdownSupported = "Markdown preview"
    
    case loggingOut = "Logging out..."
    
    case openPost = "Open post {{ postID }}"
    case postNotFound = "No posts found with the given ID."
    case users = "Users"
    case posts = "Posts"
    case search = "Search"
    case searching = "Searching"
    case searchForUsers = "Filter users by name or ID"
    case searchingLocally = "Searching for posts in your local database"
    case noResultsFound = "No results found."
    case noResultsHelp = "Not seeing what you are looking for? Planetary can only search the people and posts in your network. Right now the search only matches whole words, user IDs, and post IDs. We also may exclude posts older than 6 months to save space on your device."
    
    // MARK: - Beta 1 migration strings
    case upgradingAndRestoring = "Planetary is upgrading and restoring your messages from the network."
    case beta1MigrationComplete = "Tap on the following button to close this screen and go back to your feed."
    case beta1MigrationPleaseLeaveAppOpen = "This may take a while.\n\nPlease leave the app open until it's done.\n"
    case beta1StartUsingPlanetary =
"""
If you don't want to wait, you can
start using Planetary right away, but:
"""
    case startUsingPlanetary = "start using Planetary"
    case startUsingPlanetaryTitle = "Start Using Planetary"
    case percentComplete = "complete"
    case beta1Disclaimers =
"""

• you won't be able to post or follow until your whole feed is downloaded

• you may not see all previous messages until they are downloaded.
"""
    case areYouSure = "Are you sure?"
    case dismissMigrationEarlyMessage = "This screen will dismiss and you can use Planetary while your data continues downloading in the background. Are you sure?"
}

// MARK: - ImagePicker

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

// MARK: - New post

extension Text {

    enum NewPost: String, Localizable, CaseIterable {
        case confirmRemove = "Remove this image from the post?  You can always add it back again."
        case remove = "Remove"
    }
}

// MARK: - Offboarding

extension Text {

    enum Offboarding: String, Localizable, CaseIterable {
        case reset = "Delete"
        case resetIdentity = "Delete My Identity"
        case resetConfirmTitle = "Warning"
        case resetConfirmMessage = "Are you sure want to delete your identity from this device? You will lose this profile and all related content. This cannot be undone."
        case resetConfirmAgainTitle = "Are you sure?"
        case resetConfirmAgainMessage = "Are you really sure you want to delete your identity from this device? You will lose this profile and all related content. This cannot be undone."
        case resetFooter = "This will destroy your identity on your device. You will not be able to recover your identity, but you will be able to create a new one."
        case resetApiErrorTryAgain = "We weren't able to connect to the directory to remove you. Please try again."
        case resetBotErrorTryAgain = "Something unexpected happened but don't worry, we've made a note to fix it. Please try again."
    }
}

// MARK: - Onboarding

extension Text {

    enum Onboarding: String, Localizable, CaseIterable {
        enum StepTitle: String, Localizable, CaseIterable {
            case backup = "Okay, we've created your identity - would you like to back it up?"
            case benefits = "Planetary is a healthier way to be social"
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
            case start = "\nSocial media for humans, not algorithms."

            static var namespace: String {
                "OnboardingStepTitle"
            }
        }

        case getStartedButton = "Let's get started"

        case photoButtonAdd = "Add a photo"
        case doItLater = "I'll do it later"

        case useRealName = "Your name will be publicly visible, so feel free to use a pseudonym, or skip this part for now."

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

        case startOver = "Start Over"

        case contactsHint = "We one-way encrypt this data so we can never access it directly."
        case connect = "Connect away!"
        case notNow = "Not now"
        case contactsWIP = "Apologies, this feature is a work in progress. Tap 'OK' to see a list of recommended users to follow."
        case listMeTitle = "List me in the user directory"
        case listMeMessage = "This allows people to find you if they know your name or phone number"
        case thanksForTrying = "Thanks for trying Planetary! It's customary to use the #newpeople hashtag to introduce yourself."
        case doneOnboarding = "Phew! I'm done!"
        case earlyAccess = "This app is at an early stage. We've been focusing our time on the foundations, so there are gaps and rough bits in the UI. Bear with us!"
        case iUnderstand = "Yes, I understand"
        case followPlanetaryToggleTitle = "Follow Planetary"
        case followPlanetaryToggleDescription = "Follow the Planetary account to see posts from our team."

        case somethingWentWrong = "Oh no! Something went wrong!"
        case errorRetryMessage = "This is not your fault, we messed something up. You can try again or start over, and please come and tell one of us about it."
        case resumeRetryMessage = "This is not your fault, we messed something up. In some cases, it may mean your device cannot reach the network, and trying again later might help."

        case backupHint = "Planetary does not use passwords - you have a secret key that you need to keep safe. If you can, you should back it up. Note: this feature is still a work in progress."
        case backUp = "Yes, back up my identity"
        case bioHint = "Don't worry too much about what you say, you can change it later."

        case benefits = "🤝 On Planetary news travels from one friend to another, like it does in the real world. There are no supercomputers optimizing your experience for *engagement*. We call it a **gossip** network, and it's a healthier, happier place.\n\n👭 Building on real relationships, Planetary creates a **personal network** for you, your friends, and friends-of-friends. Your local network minimizes abusive content and spam that is typical on global platforms.\n\n🌍 We don't lock your social data into one app forever. If you stop enjoying our app you can take your data - including all your relationships - to another compatible app. Planetary is part of a **growing ecosystem** built on the Secure Scuttlebutt protocol. Refreshing, right?\n\n\n\nFind out more"
        case findOutMore = "Find out more"
        case thatSoundsGreat = "That sounds great!"

        // note that ToS and PP are used to decorate the substrings in the statement
        // this means that the text must be the same otherwise the decoration will fail
        // check out `SplashOnboardingStep` to see how it is used
        case policyStatement = "By continuing, you confirm that you agree to our Terms of Service and Privacy Policy"
        case termsOfService = "Terms of Service"
        case privacyPolicy = "Privacy Policy"
        
        case welcomeMessage = "Welcome to Planetary! We’re thrilled to have you. Here are some tips to start you on your journey:"
        case welcomeBotName = "Planetary Help"
        case welcomeBotBio = "This is a fake account used to show welcome messages to new users. To get help open a support ticket from the side menu or post with the hashtag #planetary-help."
    }
}

// MARK: - Manage Pubs

extension Text {

    enum ManagePubs: String, Localizable, CaseIterable {
        case header = "Pubs"
        case title = "Manage Pubs"
        case footer = "Pubs are relay servers that distribute messages through the scuttlebutt network. You are automatically connected to Planetary pubs, but you can connect to others if you'd prefer, or even run one yourself."
        case addingPubs = "Adding Pubs"
        case yourPubs = "Your Pubs"
        case lastWorked = "Last worked on"
        case pasteAddress = "Paste the address here"
    }
}

// MARK: - Preview

extension Text {

    enum Preview: String, Localizable, CaseIterable {
        case title = "Advanced Settings"
        case footer = "New features that are being developed and tested, and haven't found a permanent home yet in the app."
    }
}

// MARK: - Feed Algorithms

extension Text {

    enum FeedAlgorithm: String, Localizable, CaseIterable {
        case algorithms = "Algorithms"
        case feedAlgorithmTitle = "Home Feed"
        case feedAlgorithmDescription = "Choose the algorithm used to sort and filter your Home Feed."
        case recentPostsAlgorithm = "Recent posts"
        case recentPostsAlgorithmDescription = "Shows posts from the people you follow in the order they were posted."
        case recentPostsWithFollowsAlgorithm = "Recent posts and follows (default)"
        case recentPostsWithFollowsAlgorithmDescription = "Shows posts and follow messages from the people you follow in the order they were posted."
        case recentlyActivePostsWithFollowsAlgorithm = "Recently active posts and follows"
        case recentlyActivePostsWithFollowsAlgorithmDescription = "Shows posts and follow messages from the people you follow. If a message receives a reply it will be pushed back up to the top of the feed."
        case viewAlgorithmSource = "View Source Code"
        case sourceCode = "Source Code"
        case sourceCodeDescription = "Planetary's code is open source so our algorithms can be audited and even modified by our users. You can view the source code for these algorithms by tapping the button above."
    }
}

// MARK: - Public Web Hosting

extension Text {

    enum PublicWebHosting: String, Localizable, CaseIterable {
        case enabled = "Enabled"
        case title = "Public Web Hosting"
        case footer = "Opt-in to indicate you want your feed to appear on public gateways. It may take a couple of hours for the changes to be visible."
    }
}

// MARK: - Push

extension Text {

    enum Push: String, Localizable, CaseIterable {
        case enabled = "Enabled"
        case title = "Push Notifications"
        case prompt = "Push notifications for Planetary are controlled in your device's Settings app.  Would you like to open Settings now?"
        case footer = "Show a system notification when you are mentioned, replied to, or followed.  The notification infrastructure is still in development, so you may not receive notifications consistently."
    }
}

// MARK: - Notifications

extension Text {

    enum Notifications: String, Localizable, CaseIterable {
        case markAllAsRead = "Mark all as read"
    }
}

// MARK: - Report

extension Text {

    enum Reporting: String, Localizable, CaseIterable {
        case abusive = "Abusive to me or someone else"
        case copyright = "Infringes on my copyright"
        case offensive = "Offensive or inappropriate"
        case other = "Some other reason"
        case whyAreYouReportingThisPost = "Why are you reporting this post?"
    }
}

// MARK: - Block

extension Text {

    enum Blocking: String, Localizable, CaseIterable {
        case alertTitle = "Are you sure you want to block {{ name }}? You will no longer see each other's content or be able to contact each other."
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
        case debugFooter = "This is where we let you shoot yourself in the foot. Here is where you get at your private key, set new keys, see information about the network, pub's, and all sorts of things. Careful what you change in this menu, you can break things with these options."
        case resetForkedFeedProtection = "Reset Forked Feed Protection"
        case resetForkedFeedProtectionDescription = "This will reset the number of published messages associated with your identity to the number currently in your database. It will also turn forked feed protection on if it is off. You should only do this if you are sure all of your published messages are on this device. Are you sure?"
        case reset = "Reset"
        case noBotConfigured = "No bot configured."
    }
}

extension Text {
    
    enum Error: String, Localizable, CaseIterable {
        case login = "The peer to peer engine failed to start. Please use Restart to repair and restart it or use Ignore to browse the content that is already fetched to your device."
        case unexpected = "Something unexpected happened."
        case supportNotConfigured = "Support is not configured."
        case invitationRedemptionFailed = "Could not join {{ starName }}. Please try again or contact support."
        case cannotPublishBecauseRestoring = "Planetary is currently restoring your data from the network, and cannot publish new posts at this time."
        case restoring = "Planetary is currently restoring your data from the network."
        case invalidAppConfiguration = "Invalid app configuration"
        case couldNotGenerateLink = "Could not generate link."
    }
}

extension Text {
    enum Channel: String, Localizable, CaseIterable {
        case one = "channel"
        case many = "channels"
    }
}

extension Text {
    enum Post: String, Localizable, CaseIterable {
        case one = "post"
        case many = "posts"
    }
}

extension Text {
    enum Report: String, Localizable, CaseIterable {
        case somebody = "Somebody"
        case feedFollowed = "%@ started following you"
        case postReplied = "%@ replied to your post"
        case feedMentioned = "%@ mentioned you in a post"
        case messageLiked = "%@ liked your post"
    }
}
