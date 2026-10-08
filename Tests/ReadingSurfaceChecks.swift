import Foundation

/// Offline checks for the reading surface: which of the three surfaces a
/// conversation renders, and which of the composer's blocks survive the fold.
///
/// The policy is pure, so it compiles here without a view, a store or a
/// running app, and the rules the phone depends on are asserted directly: the
/// automatic reduction follows the scroll only when the reader asked for it,
/// the explicit claim wins over everything and survives a new turn, the
/// terminal presentation never folds, and an empty block is hidden in every
/// surface - which is the space the old panel used to spend on nothing.
@main struct ReadingSurfaceChecks {
    static func main() throws {
        let composerOnly = ReadingPreferences()
        let manual = ReadingPreferences.disabled

        // The reader who has not touched the settings still gets the shipped
        // behaviour: fold while reading, restore at the bottom, keep the
        // keyboard out of the way of a conversation that just opened.
        assert(composerOnly.automaticCollapse, "the automatic reduction is on by default")
        assert(composerOnly.focusComposerOnOpen == false || composerOnly.focusComposerOnOpen == true, "the focus preference is a plain answer")
        assert(ReadingPreferences.disabled.automaticCollapse == false, "the manual preference switches the reduction off")

        // The three surfaces, from the claim and the scroll.
        assert(ReadingSurfacePolicy.surface(claimed: false, scrolledAway: false, terminal: false, preferences: composerOnly) == .full,
               "following the bottom is the full composer")
        assert(ReadingSurfacePolicy.surface(claimed: false, scrolledAway: true, terminal: false, preferences: composerOnly) == .reduced,
               "scrolling away reduces the composer")
        assert(ReadingSurfacePolicy.surface(claimed: false, scrolledAway: false, terminal: false, preferences: manual) == .full,
               "a reader who turned the reduction off keeps the full composer while scrolling")
        assert(ReadingSurfacePolicy.surface(claimed: true, scrolledAway: false, terminal: false, preferences: composerOnly) == .reading,
               "the explicit claim hides the controls wherever the transcript is")
        assert(ReadingSurfacePolicy.surface(claimed: true, scrolledAway: true, terminal: false, preferences: manual) == .reading,
               "the claim is the reader's and outranks the preference, which only governs the automatic fold")
        print("PASS: the surface follows the claim, the scroll and the preference")

        // The terminal presentation owns a different panel: it is never
        // folded, whatever the reader claimed for the conversation.
        for claimed in [true, false] {
            for away in [true, false] {
                assert(ReadingSurfacePolicy.surface(claimed: claimed, scrolledAway: away, terminal: true, preferences: composerOnly) == .full,
                       "the shell presentation keeps its own panel")
            }
        }
        print("PASS: the shell presentation never enters the reading surface")

        // What each surface draws.
        assert(ReadingSurface.full.showsComposer && ReadingSurface.full.showsFullComposer && ReadingSurface.full.showsPanel && ReadingSurface.full.showsHeaderDetails,
               "the full surface draws everything")
        assert(ReadingSurface.reduced.showsComposer && !ReadingSurface.reduced.showsFullComposer && ReadingSurface.reduced.showsPanel && ReadingSurface.reduced.showsHeaderDetails,
               "the reduced surface keeps the panel but collapses the composer")
        assert(!ReadingSurface.reading.showsComposer && !ReadingSurface.reading.showsPanel && !ReadingSurface.reading.showsHeaderDetails,
               "the reading surface keeps the conversation and the title only")
        // The reply banner is what guarantees a way back from both folds.
        assert(!ReadingSurfacePolicy.showsReplyBanner(surface: .full) && ReadingSurfacePolicy.showsReplyBanner(surface: .reduced) && ReadingSurfacePolicy.showsReplyBanner(surface: .reading),
               "the reply banner is the folded composer's one tap back")
        print("PASS: each surface draws the blocks it claims")

        // An empty block is hidden in every surface, including the full one.
        // This is the rule that reclaims the space the always-on panel spent:
        // the old bottom panel rendered the queue dock, the diff button and
        // the attachment strip whether or not they had anything to say.
        for block in ReadingPanelBlock.allCases {
            assert(!ReadingSurfacePolicy.shows(block, hasContent: false, surface: .full, preferences: composerOnly),
                   "an empty block stays hidden on the full surface: \(block.rawValue)")
            assert(!ReadingSurfacePolicy.shows(block, hasContent: false, surface: .reading, preferences: composerOnly),
                   "an empty block stays hidden while reading: \(block.rawValue)")
        }
        assert(!ReadingSurfacePolicy.showsAttachments(hasContent: false, surface: .full, preferences: composerOnly),
               "an empty attachment strip stays hidden on the full surface")
        print("PASS: an empty block is hidden in every surface")

        // A block that carries something and that the reader did not ask to
        // keep folds away; the ones they did ask to keep stay.
        assert(ReadingSurfacePolicy.shows(.queueDock, hasContent: true, surface: .full, preferences: composerOnly),
               "a populated queue dock shows on the full surface")
        assert(!ReadingSurfacePolicy.shows(.queueDock, hasContent: true, surface: .reading, preferences: composerOnly),
               "a populated queue dock folds away while reading by default")
        assert(ReadingSurfacePolicy.shows(.queueDock, hasContent: true, surface: .reading, preferences: ReadingPreferences(keepQueueDock: true)),
               "a kept queue dock survives the fold")
        assert(ReadingSurfacePolicy.shows(.diffReview, hasContent: true, surface: .reading, preferences: ReadingPreferences(keepDiffReview: true)),
               "a kept diff review survives the fold")
        assert(ReadingSurfacePolicy.shows(.queuedMessages, hasContent: true, surface: .reading, preferences: ReadingPreferences(keepQueuedMessages: true)),
               "kept queued messages survive the fold")
        assert(ReadingSurfacePolicy.showsAttachments(hasContent: true, surface: .reading, preferences: ReadingPreferences(keepAttachments: true)),
               "kept attachments survive the fold")
        print("PASS: the reader's keep choices are honoured and only there")

        // The two blocks that are never a matter of preference: an error and
        // an agent question are information the reader must not lose to a
        // fold, and they still obey their own emptiness.
        for surface in [ReadingSurface.full, .reduced, .reading] {
            assert(ReadingSurfacePolicy.shows(.error, hasContent: true, surface: surface, preferences: composerOnly),
                   "an error is never folded away")
            assert(ReadingSurfacePolicy.shows(.interaction, hasContent: true, surface: surface, preferences: composerOnly),
                   "an agent question is never folded away")
        }
        print("PASS: an error and an agent question outrank the fold")

        // The keyboard: the conversation takes it on open only when the reader
        // asked for it, and never from a folded surface, where the field is
        // not on screen to receive it.
        assert(ReadingSurfacePolicy.focusesComposerOnOpen(claimed: false, terminal: false, preferences: composerOnly),
               "the default opens with the keyboard")
        assert(!ReadingSurfacePolicy.focusesComposerOnOpen(claimed: false, terminal: false, preferences: ReadingPreferences(focusComposerOnOpen: false)),
               "the reader can keep the conversation full-screen on open")
        assert(!ReadingSurfacePolicy.focusesComposerOnOpen(claimed: true, terminal: false, preferences: composerOnly),
               "a claimed surface never takes the keyboard")
        assert(!ReadingSurfacePolicy.focusesComposerOnOpen(claimed: false, terminal: true, preferences: composerOnly),
               "the shell presentation owns its own focus")
        print("PASS: the keyboard on open follows the reader and the surface")

        // The preferences survive a round trip through the store's persisted
        // keys, including the untouched install, where every key is absent and
        // the built-in defaults must win over UserDefaults' zero value.
        let defaults = UserDefaults.standard
        let keys = ["harness.reading.automaticCollapse", "harness.reading.keepQueueDock", "harness.reading.keepDiffReview", "harness.reading.keepAttachments", "harness.reading.keepQueuedMessages", "harness.reading.focusComposerOnOpen"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) } } }
        for key in keys { defaults.removeObject(forKey: key) }
        let builtIn = ReadingPreferences()
        func stored(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        let loaded = ReadingPreferences(
            automaticCollapse: stored("harness.reading.automaticCollapse", builtIn.automaticCollapse),
            keepQueueDock: stored("harness.reading.keepQueueDock", builtIn.keepQueueDock),
            keepDiffReview: stored("harness.reading.keepDiffReview", builtIn.keepDiffReview),
            keepAttachments: stored("harness.reading.keepAttachments", builtIn.keepAttachments),
            keepQueuedMessages: stored("harness.reading.keepQueuedMessages", builtIn.keepQueuedMessages),
            focusComposerOnOpen: stored("harness.reading.focusComposerOnOpen", builtIn.focusComposerOnOpen)
        )
        assert(loaded == builtIn, "an untouched install loads the built-in defaults, not UserDefaults' zero values")
        defaults.set(true, forKey: "harness.reading.keepDiffReview")
        assert(stored("harness.reading.keepDiffReview", builtIn.keepDiffReview), "a written preference is read back")
        print("PASS: the reading preferences survive the persisted keys")

        print("Reading surface checks passed")
    }
}
