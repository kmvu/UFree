//
//  UFreeCoachTips.swift
//  UFree
//
//  One-shot TipKit coach-marks for hidden Who's Free / Schedule actions.
//

import TipKit

struct PartialDayWindowTip: Tip {
    var title: Text {
        Text("Set a time window")
    }

    var message: Text {
        Text("Long-press a day to mark just an evening or afternoon — not the whole day.")
    }
}

struct BothFreeTip: Tip {
    var title: Text {
        Text("You’re both free")
    }

    var message: Text {
        Text("A “Both” cell means you and that friend are free the same day. That’s your hang window.")
    }
}

struct BatchNudgeTip: Tip {
    var title: Text {
        Text("Nudge everyone who’s free")
    }

    var message: Text {
        Text("When two or more friends are free, one tap asks them all about that day.")
    }
}

enum UFreeCoachTips {
    static func configureIfNeeded() {
        guard !TestConfiguration.isTesting else {
            Tips.hideAllTipsForTesting()
            return
        }
        try? Tips.configure([.displayFrequency(.immediate)])
    }
}
