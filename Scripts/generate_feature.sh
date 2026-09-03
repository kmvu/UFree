#!/usr/bin/env bash
# Deprecated — do not use.
#
# This generator targeted a UIKit / Combine Clean Architecture layout that does
# not match UFree (SwiftUI + repository protocols under UFree/Features and
# UFree/Core). Paths and templates are wrong for this repo.
#
# See Docs/AGENTS.md and Docs/ENGINEERING_GUIDE.md for conventions instead.

set -euo pipefail
echo "❌ Scripts/generate_feature.sh is deprecated (wrong UIKit paths for UFree)." >&2
echo "   Follow Docs/AGENTS.md and Docs/ENGINEERING_GUIDE.md when adding features." >&2
exit 1
