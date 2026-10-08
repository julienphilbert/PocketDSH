import Foundation

/// The reading surface of a conversation: how much of the screen the
/// conversation itself gets, and how much the controls around it keep.
///
/// The problem this type exists for: on a phone the transcript is read
/// through a keyhole. The keyboard covers the bottom third, the word
/// suggestion bar sits above it, and the composer panel - an input field, a
/// row of model/preset/control chips, the queue dock, the diff review button
/// and the attachment strip - is painted in full even when every one of those
/// blocks is empty. Reading a message that is not at the bottom of the
/// conversation leaves roughly a third of the screen for the conversation
/// itself.
///
/// Two reductions answer it, and they are deliberately different things:
///
///   * `.reduced` follows the reader. Once the transcript is scrolled away
///     from the bottom the composer collapses to its one-line reply banner
///     and the conditional blocks that have nothing to show stop rendering.
///     Scrolling back to the bottom restores the full composer, so following
///     the live turn is never hindered. This is what `automaticCollapse`
///     switches off for readers who want nothing to move on its own.
///
///   * `.reading` is claimed explicitly, by the swipe or the chevron. It
///     hides the composer and the whole bottom panel and leaves the
///     conversation and the navigation title. It is sticky: a new turn or a
///     new message does not silently reopen the controls, because reopening
///     is one tap away and losing the surface to a streaming turn would be
///     worse than leaving it closed.
///
/// The policy is pure so the rules can be checked offline against the same
/// store state the view reads - the store owns the flags, this type owns the
/// decision.
enum ReadingSurface: Equatable {
    case full
    case reduced
    case reading

    /// Whether the composer is drawn at all.
    var showsComposer: Bool { self != .reading }
    /// Whether the composer is drawn in its full form, fields and chips both.
    var showsFullComposer: Bool { self == .full }
    /// Whether the bottom panel is drawn at all.
    var showsPanel: Bool { self != .reading }
    /// Whether the navigation header keeps its secondary lines - the working
    /// directory, the model, the status and the hint row. The header loses
    /// them under `.reading` and only under it, so the title stays reachable
    /// to leave the state.
    var showsHeaderDetails: Bool { self != .reading }
}

/// What the reader keeps when the surface folds down, as they configured it.
///
/// Every field is a "keep the block visible while the conversation is being
/// read" answer, and the default is the opposite for the ones that only
/// matter while composing. A block the reader asked to keep still obeys the
/// block's own emptiness: an empty queue dock stays hidden under `.reading`
/// because there is nothing to hide.
struct ReadingPreferences: Equatable {
    /// Collapse the composer to its reply banner as soon as the transcript
    /// leaves the bottom. Off means the composer changes only on the explicit
    /// swipe, the chevron or the reply banner.
    var automaticCollapse = true
    /// Keep the queue dock while reading.
    var keepQueueDock = false
    /// Keep the diff review button while reading.
    var keepDiffReview = false
    /// Keep the shell attachment strip while reading.
    var keepAttachments = false
    /// Keep the queued-messages disclosure while reading.
    var keepQueuedMessages = false
    /// Focus the composer when a conversation opens, which brings the
    /// keyboard and its suggestion bar up before anything is typed. Off
    /// leaves the conversation full-screen until the reader taps a field.
    var focusComposerOnOpen = true

    static let disabled = ReadingPreferences(automaticCollapse: false, keepQueueDock: true, keepDiffReview: true, keepAttachments: true, keepQueuedMessages: true, focusComposerOnOpen: true)
    static let composerOnly = ReadingPreferences(automaticCollapse: true, keepQueueDock: false, keepDiffReview: false, keepAttachments: false, keepQueuedMessages: false, focusComposerOnOpen: true)
}

/// The blocks the bottom panel may draw, named so the check can assert the
/// fold without a view.
enum ReadingPanelBlock: String, CaseIterable {
    case error
    case interaction
    case queueDock
    case diffReview
    case queuedMessages
}

enum ReadingSurfacePolicy {
    /// The surface a conversation is on.
    ///
    /// `claimed` is the reader's explicit choice, `scrolledAway` says the
    /// transcript is no longer following its bottom, and `terminal` is the
    /// shell presentation - which is a different surface with a different
    /// panel, so it stays out of the fold entirely.
    static func surface(claimed: Bool, scrolledAway: Bool, terminal: Bool, preferences: ReadingPreferences) -> ReadingSurface {
        if claimed && !terminal { return .reading }
        if !terminal && preferences.automaticCollapse && scrolledAway { return .reduced }
        return .full
    }

    /// Whether one bottom-panel block is drawn. `hasContent` is the block's
    /// own condition - a queue with no items, a diff that cannot be reviewed,
    /// no attachments - and it is never overridden: folding hides layout, not
    /// information. A block that is empty is hidden in every surface,
    /// including the full one, which is what reclaims the vertical space the
    /// old panel spent on nothing.
    static func shows(_ block: ReadingPanelBlock, hasContent: Bool, surface: ReadingSurface, preferences: ReadingPreferences) -> Bool {
        guard hasContent else { return false }
        switch block {
        case .error: return true
        case .interaction: return true
        case .queueDock: return surface == .full || preferences.keepQueueDock
        case .diffReview: return surface == .full || preferences.keepDiffReview
        case .queuedMessages: return surface == .full || preferences.keepQueuedMessages
        }
    }

    /// Whether an attachment block is drawn. It belongs to the composer
    /// rather than the panel - on the native backend it is a strip above the
    /// fields - so the full surface always keeps it.
    static func showsAttachments(hasContent: Bool, surface: ReadingSurface, preferences: ReadingPreferences) -> Bool {
        guard hasContent else { return false }
        return surface == .full || preferences.keepAttachments
    }

    /// Whether a conversation that just opened should take the keyboard.
    static func focusesComposerOnOpen(claimed: Bool, terminal: Bool, preferences: ReadingPreferences) -> Bool {
        !claimed && !terminal && preferences.focusComposerOnOpen
    }

    /// Whether the reply banner is the composer's visible form: the banner
    /// replaces the fields and chips in both folded surfaces, so the reader
    /// always has one tap back to composing.
    static func showsReplyBanner(surface: ReadingSurface) -> Bool {
        surface != .full
    }
}
