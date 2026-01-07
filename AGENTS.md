# Agent Instructions for UFree Project

## CRITICAL: Path Format

**MUST USE UNESCAPED SPACES IN FILE PATHS**

❌ WRONG:
```
/Users/KhangVu/Documents/Development/git_project/Khang\ Business\ Projects/UFree
```

✅ CORRECT:
```
/Users/KhangVu/Documents/Development/git_project/Khang Business Projects/UFree
```

Always use the absolute path with literal spaces, not escaped backslashes. This applies to all `create_file`, `Read`, `edit_file`, `Bash`, and other file operations.

---

## Project Structure

- **UFree/**: Main app source
- **UFreeTests/**: Unit tests
- **UFreeUITests/**: UI tests
- **Docs/**: Documentation

---

## Recent Work

- **Sprint 4 ✅ COMPLETE**: Two-Way Handshake & Phone Search
  - **Phone Search** (Privacy-Safe): findUserByPhoneNumber() with blind index pattern (clean → hash → Firestore). TextField with phonePad keyboard, clears after add, prevents self-add via Auth user ID check.
  - **Friend Requests** (Handshake): sendFriendRequest() creates pending. observeIncomingRequests() AsyncStream for real-time. acceptFriendRequest() with atomic batch write. declineFriendRequest() marks declined. View lifecycle: .task { listenToRequests() } on appear, .onDisappear { stopListening() } to save battery/data.
  - **Real-Time Listeners**: AsyncStream pattern instead of Combine. Proper cleanup on task cancellation.
  - **Privacy-First**: Schedule visibility only after both parties consent.
  - **Haptics**: medium() on search/send, success() on accept, warning() on decline.
  - **Tests Optimized**: 15+ focused unit tests (phone search workflows, handshake scenarios, observation, lifecycle).
  - **Files**: FriendRequest.swift, FriendRepository.swift (protocol + Firebase), FriendsViewModel.swift, FriendsView.swift, MockFriendRepository.swift, FriendsViewModelTests.swift, FriendsHandshakeTests.swift
