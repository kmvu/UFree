/**
 * Firestore security rules tests for UFree Phase 1 privacy model.
 *
 * Run from repo root via: npm --prefix firebase-tests test
 * (starts the Firestore emulator, applies ../firestore.rules, then exits)
 */

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { readFileSync } = require("fs");
const { resolve } = require("path");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  arrayUnion,
  arrayRemove,
  writeBatch,
} = require("firebase/firestore");

const RULES_PATH = resolve(__dirname, "../firestore.rules");
const PROJECT_ID = "ufree-rules-test";

/** @type {import("@firebase/rules-unit-testing").RulesTestEnvironment} */
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function unauthedDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seedAliceAndBob() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users/alice"), {
      displayName: "Alice",
      friendIds: [],
      hashedPhoneNumbers: ["hash_alice"],
    });
    await setDoc(doc(db, "users/bob"), {
      displayName: "Bob",
      friendIds: [],
      hashedPhoneNumbers: ["hash_bob"],
    });
    await setDoc(doc(db, "users/mallory"), {
      displayName: "Mallory",
      friendIds: [],
    });
    await setDoc(doc(db, "publicProfiles/alice"), { displayName: "Alice" });
    await setDoc(doc(db, "publicProfiles/bob"), { displayName: "Bob" });
    await setDoc(doc(db, "phoneDirectory/hash_alice"), { uid: "alice" });
    await setDoc(doc(db, "phoneDirectory/hash_bob"), { uid: "bob" });
    await setDoc(doc(db, "users/bob/availability/2099-01-01"), {
      dateString: "2099-01-01",
      status: 1,
      timeBlocks: [],
    });
  });
}

async function seedAcceptedFriends() {
  await seedAliceAndBob();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "friendRequests/bob_alice"), {
      fromId: "bob",
      fromName: "Bob",
      toId: "alice",
      status: "accepted",
      timestamp: new Date(),
    });
    await setDoc(doc(db, "users/alice"), {
      displayName: "Alice",
      friendIds: ["bob"],
      hashedPhoneNumbers: ["hash_alice"],
    });
    await setDoc(doc(db, "users/bob"), {
      displayName: "Bob",
      friendIds: ["alice"],
      hashedPhoneNumbers: ["hash_bob"],
    });
  });
}

// ── Users / availability reads ──────────────────────────────────────────────

describe("user profile reads", () => {
  it("denies unauthenticated reads", async () => {
    await seedAliceAndBob();
    await assertFails(getDoc(doc(unauthedDb(), "users/alice")));
  });

  it("allows owner to read own profile", async () => {
    await seedAliceAndBob();
    await assertSucceeds(getDoc(doc(authedDb("alice"), "users/alice")));
  });

  it("denies stranger reading another profile", async () => {
    await seedAliceAndBob();
    await assertFails(getDoc(doc(authedDb("mallory"), "users/alice")));
  });

  it("allows accepted friend to read profile", async () => {
    await seedAcceptedFriends();
    await assertSucceeds(getDoc(doc(authedDb("alice"), "users/bob")));
  });

  it("denies listing all users", async () => {
    await seedAliceAndBob();
    await assertFails(getDocs(collection(authedDb("mallory"), "users")));
  });
});

describe("availability reads", () => {
  it("denies stranger reading availability", async () => {
    await seedAliceAndBob();
    await assertFails(
      getDoc(doc(authedDb("mallory"), "users/bob/availability/2099-01-01"))
    );
  });

  it("allows owner to read own availability", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      getDoc(doc(authedDb("bob"), "users/bob/availability/2099-01-01"))
    );
  });

  it("allows accepted friend to read availability", async () => {
    await seedAcceptedFriends();
    await assertSucceeds(
      getDoc(doc(authedDb("alice"), "users/bob/availability/2099-01-01"))
    );
  });

  it("allows owner to write availability within caps", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      setDoc(doc(authedDb("alice"), "users/alice/availability/2099-02-01"), {
        dateString: "2099-02-01",
        status: 1,
        timeBlocks: [],
      })
    );
  });

  it("denies peer writing someone else's availability", async () => {
    await seedAcceptedFriends();
    await assertFails(
      setDoc(doc(authedDb("alice"), "users/bob/availability/2099-02-01"), {
        dateString: "2099-02-01",
        status: 1,
        timeBlocks: [],
      })
    );
  });
});

// ── publicProfiles / phoneDirectory ─────────────────────────────────────────

describe("publicProfiles", () => {
  it("allows authenticated get, denies list", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      getDoc(doc(authedDb("mallory"), "publicProfiles/alice"))
    );
    await assertFails(
      getDocs(collection(authedDb("mallory"), "publicProfiles"))
    );
  });

  it("allows owner to write displayName only", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      setDoc(doc(authedDb("alice"), "publicProfiles/alice"), {
        displayName: "Alice Updated",
      })
    );
    await assertFails(
      setDoc(doc(authedDb("alice"), "publicProfiles/alice"), {
        displayName: "Alice",
        secret: "nope",
      })
    );
    await assertFails(
      setDoc(doc(authedDb("mallory"), "publicProfiles/alice"), {
        displayName: "Hijacked",
      })
    );
  });
});

describe("phoneDirectory", () => {
  it("allows authenticated get, denies list", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      getDoc(doc(authedDb("mallory"), "phoneDirectory/hash_alice"))
    );
    await assertFails(
      getDocs(collection(authedDb("mallory"), "phoneDirectory"))
    );
  });

  it("allows first writer to claim a hash for themselves", async () => {
    await assertSucceeds(
      setDoc(doc(authedDb("carol"), "phoneDirectory/hash_carol"), {
        uid: "carol",
      })
    );
  });

  it("denies claiming a hash for another uid", async () => {
    await assertFails(
      setDoc(doc(authedDb("mallory"), "phoneDirectory/hash_victim"), {
        uid: "victim",
      })
    );
  });

  it("denies overwriting an existing claim", async () => {
    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("mallory"), "phoneDirectory/hash_alice"), {
        uid: "mallory",
      })
    );
    await assertFails(
      updateDoc(doc(authedDb("alice"), "phoneDirectory/hash_alice"), {
        uid: "alice2",
      })
    );
  });

  it("allows owner to delete their own directory entry", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      deleteDoc(doc(authedDb("alice"), "phoneDirectory/hash_alice"))
    );
  });
});

// ── Friend requests + friendIds ─────────────────────────────────────────────

describe("friendRequests", () => {
  it("requires deterministic fromId_toId document id", async () => {
    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("bob"), "friendRequests/random-id"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      })
    );
    await assertSucceeds(
      setDoc(doc(authedDb("bob"), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      })
    );
  });

  it("denies creating a request to yourself", async () => {
    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("alice"), "friendRequests/alice_alice"), {
        fromId: "alice",
        fromName: "Alice",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      })
    );
  });

  it("allows recipient to accept; freezes identity fields", async () => {
    await seedAliceAndBob();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      });
    });

    await assertSucceeds(
      updateDoc(doc(authedDb("alice"), "friendRequests/bob_alice"), {
        status: "accepted",
      })
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      });
    });

    await assertFails(
      updateDoc(doc(authedDb("alice"), "friendRequests/bob_alice"), {
        status: "accepted",
        fromId: "mallory",
      })
    );
    await assertFails(
      updateDoc(doc(authedDb("bob"), "friendRequests/bob_alice"), {
        status: "accepted",
      })
    );
  });
});

describe("friendIds mutations", () => {
  it("denies peer self-add without an accepted request", async () => {
    await seedAliceAndBob();
    await assertFails(
      updateDoc(doc(authedDb("mallory"), "users/alice"), {
        friendIds: arrayUnion("mallory"),
      })
    );
  });

  it("allows peer self-add when accepted request exists in the same batch", async () => {
    await seedAliceAndBob();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      });
    });

    // Simulate accept batch: mark accepted + both friendIds updates.
    const db = authedDb("alice");
    const batch = writeBatch(db);
    batch.update(doc(db, "friendRequests/bob_alice"), { status: "accepted" });
    batch.update(doc(db, "users/alice"), { friendIds: arrayUnion("bob") });
    batch.update(doc(db, "users/bob"), { friendIds: arrayUnion("alice") });
    await assertSucceeds(batch.commit());
  });

  it("allows peer self-remove (unfriend) without a request", async () => {
    await seedAcceptedFriends();
    await assertSucceeds(
      updateDoc(doc(authedDb("alice"), "users/bob"), {
        friendIds: arrayRemove("alice"),
      })
    );
  });

  it("denies peer modifying fields other than friendIds", async () => {
    await seedAcceptedFriends();
    await assertFails(
      updateDoc(doc(authedDb("alice"), "users/bob"), {
        friendIds: arrayRemove("alice"),
        displayName: "Hacked",
      })
    );
  });

  it("allows owner to update displayName and hashes", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      setDoc(
        doc(authedDb("alice"), "users/alice"),
        {
          displayName: "Alice 2",
          hashedPhoneNumbers: ["hash_alice", "hash_alice_e164"],
          friendIds: [],
        },
        { merge: true }
      )
    );
  });
});

// ── Notifications ───────────────────────────────────────────────────────────

describe("notifications", () => {
  it("denies arbitrary inbox writes from strangers", async () => {
    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("mallory"), "users/alice/notifications/n1"), {
        recipientId: "alice",
        senderId: "mallory",
        senderName: "Mallory",
        type: "nudge",
        date: new Date(),
        isRead: false,
      })
    );
  });

  it("allows friendRequest notification when pending request exists", async () => {
    await seedAliceAndBob();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      });
    });

    await assertSucceeds(
      setDoc(doc(authedDb("bob"), "users/alice/notifications/n1"), {
        recipientId: "alice",
        senderId: "bob",
        senderName: "Bob",
        type: "friendRequest",
        date: new Date(),
        isRead: false,
        relatedRequestId: "bob_alice",
      })
    );
  });

  it("allows nudge between mutual friends only", async () => {
    await seedAcceptedFriends();
    await assertSucceeds(
      setDoc(doc(authedDb("alice"), "users/bob/notifications/nudge1"), {
        recipientId: "bob",
        senderId: "alice",
        senderName: "Alice",
        type: "nudge",
        date: new Date(),
        isRead: false,
        targetDateString: "2099-01-01",
      })
    );

    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("alice"), "users/bob/notifications/nudge2"), {
        recipientId: "bob",
        senderId: "alice",
        senderName: "Alice",
        type: "nudge",
        date: new Date(),
        isRead: false,
      })
    );
  });

  it("denies create when recipientId does not match path", async () => {
    await seedAcceptedFriends();
    await assertFails(
      setDoc(doc(authedDb("alice"), "users/bob/notifications/bad"), {
        recipientId: "mallory",
        senderId: "alice",
        senderName: "Alice",
        type: "nudge",
        date: new Date(),
        isRead: false,
      })
    );
  });

  it("allows owner to read and update own inbox", async () => {
    await seedAcceptedFriends();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users/bob/notifications/n1"), {
        recipientId: "bob",
        senderId: "alice",
        senderName: "Alice",
        type: "nudge",
        date: new Date(),
        isRead: false,
      });
    });

    await assertSucceeds(
      getDoc(doc(authedDb("bob"), "users/bob/notifications/n1"))
    );
    await assertFails(
      getDoc(doc(authedDb("alice"), "users/bob/notifications/n1"))
    );
    await assertSucceeds(
      updateDoc(doc(authedDb("bob"), "users/bob/notifications/n1"), {
        isRead: true,
      })
    );
  });
});

// ── Account deletion (owner / participant deletes) ──────────────────────────

describe("account deletion", () => {
  it("allows owner to delete their user doc; denies strangers", async () => {
    await seedAliceAndBob();
    await assertFails(deleteDoc(doc(authedDb("mallory"), "users/alice")));
    await assertSucceeds(deleteDoc(doc(authedDb("alice"), "users/alice")));
  });

  it("allows owner to delete publicProfiles and phoneDirectory entries", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      deleteDoc(doc(authedDb("alice"), "publicProfiles/alice"))
    );
    await assertSucceeds(
      deleteDoc(doc(authedDb("alice"), "phoneDirectory/hash_alice"))
    );
    await assertFails(
      deleteDoc(doc(authedDb("mallory"), "publicProfiles/bob"))
    );
  });

  it("allows either friend-request participant to delete the request", async () => {
    await seedAliceAndBob();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      });
      await setDoc(doc(context.firestore(), "friendRequests/alice_carol"), {
        fromId: "alice",
        fromName: "Alice",
        toId: "carol",
        status: "pending",
        timestamp: new Date(),
      });
    });

    await assertSucceeds(
      deleteDoc(doc(authedDb("alice"), "friendRequests/bob_alice"))
    );
    await assertSucceeds(
      deleteDoc(doc(authedDb("alice"), "friendRequests/alice_carol"))
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "friendRequests/bob_mallory"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "mallory",
        status: "pending",
        timestamp: new Date(),
      });
    });
    await assertFails(
      deleteDoc(doc(authedDb("alice"), "friendRequests/bob_mallory"))
    );
  });

  it("allows owner to delete own availability and notifications", async () => {
    await seedAliceAndBob();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users/alice/availability/2099-01-01"), {
        dateString: "2099-01-01",
        status: 1,
        timeBlocks: [],
      });
      await setDoc(doc(context.firestore(), "users/alice/notifications/n1"), {
        recipientId: "alice",
        senderId: "bob",
        senderName: "Bob",
        type: "nudge",
        date: new Date(),
        isRead: false,
      });
    });

    await assertFails(
      deleteDoc(doc(authedDb("mallory"), "users/alice/notifications/n1"))
    );
    await assertSucceeds(
      deleteDoc(doc(authedDb("alice"), "users/alice/availability/2099-01-01"))
    );
    await assertSucceeds(
      deleteDoc(doc(authedDb("alice"), "users/alice/notifications/n1"))
    );
  });

  it("allows deleting user to remove self from a peer friendIds list", async () => {
    await seedAcceptedFriends();
    // Alice (account being deleted) removes herself from Bob's friendIds — peer self-remove.
    await assertSucceeds(
      updateDoc(doc(authedDb("alice"), "users/bob"), {
        friendIds: arrayRemove("alice"),
      })
    );
    await assertSucceeds(deleteDoc(doc(authedDb("alice"), "users/alice")));
  });

  it("lets owner probe a wiped users doc; former friends get permission-denied", async () => {
    await seedAcceptedFriends();
    await assertSucceeds(deleteDoc(doc(authedDb("alice"), "users/alice")));
    // Friend get rules need resource.data; missing docs leave resource null → deny.
    await assertFails(getDoc(doc(authedDb("bob"), "users/alice")));
    // Owner path does not touch resource, so Alice can observe the wipe.
    const snap = await assertSucceeds(getDoc(doc(authedDb("alice"), "users/alice")));
    if (snap.exists()) {
      throw new Error("expected wiped users/alice document to be missing");
    }
  });
});

// ── Phase 6.75: caps, notification branches, decline, create, lists ──────────

function tenTimeBlocks() {
  return Array.from({ length: 10 }, (_, i) => ({
    id: `block-${i}`,
    start: i,
    end: i + 1,
  }));
}

describe("availability caps", () => {
  it("allows owner write with 10 timeBlocks", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      setDoc(doc(authedDb("alice"), "users/alice/availability/2099-03-01"), {
        dateString: "2099-03-01",
        status: 1,
        timeBlocks: tenTimeBlocks(),
      })
    );
  });

  it("denies owner write with 11 timeBlocks", async () => {
    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("alice"), "users/alice/availability/2099-03-02"), {
        dateString: "2099-03-02",
        status: 1,
        timeBlocks: [...tenTimeBlocks(), { id: "block-10", start: 10, end: 11 }],
      })
    );
  });

  it("denies availability doc with more than 10 top-level fields", async () => {
    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("alice"), "users/alice/availability/2099-03-03"), {
        dateString: "2099-03-03",
        status: 1,
        timeBlocks: [],
        extra1: 1,
        extra2: 2,
        extra3: 3,
        extra4: 4,
        extra5: 5,
        extra6: 6,
        extra7: 7,
        extra8: 8,
      })
    );
  });
});

describe("notification type branches", () => {
  it("allows friendAccepted when an accepted request exists", async () => {
    await seedAcceptedFriends();
    await assertSucceeds(
      setDoc(doc(authedDb("alice"), "users/bob/notifications/accepted1"), {
        recipientId: "bob",
        senderId: "alice",
        senderName: "Alice",
        type: "friendAccepted",
        date: new Date(),
        isRead: false,
        relatedRequestId: "bob_alice",
      })
    );
  });

  it("denies friendAccepted without an accepted request", async () => {
    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("alice"), "users/bob/notifications/accepted2"), {
        recipientId: "bob",
        senderId: "alice",
        senderName: "Alice",
        type: "friendAccepted",
        date: new Date(),
        isRead: false,
      })
    );
  });

  it("allows nudgeReply between mutual friends", async () => {
    await seedAcceptedFriends();
    await assertSucceeds(
      setDoc(doc(authedDb("bob"), "users/alice/notifications/reply1"), {
        recipientId: "alice",
        senderId: "bob",
        senderName: "Bob",
        type: "nudgeReply",
        date: new Date(),
        isRead: false,
        targetDateString: "2099-01-01",
        nudgeResponse: "imIn",
      })
    );
  });

  it("denies nudgeReply from a stranger", async () => {
    await seedAliceAndBob();
    await assertFails(
      setDoc(doc(authedDb("mallory"), "users/alice/notifications/reply2"), {
        recipientId: "alice",
        senderId: "mallory",
        senderName: "Mallory",
        type: "nudgeReply",
        date: new Date(),
        isRead: false,
        nudgeResponse: "imIn",
      })
    );
  });

  it("denies notification type outside the allowed enum", async () => {
    await seedAcceptedFriends();
    await assertFails(
      setDoc(doc(authedDb("alice"), "users/bob/notifications/spam"), {
        recipientId: "bob",
        senderId: "alice",
        senderName: "Alice",
        type: "spam",
        date: new Date(),
        isRead: false,
      })
    );
  });
});

describe("friend request decline and re-send", () => {
  it("allows recipient to decline; freezes further updates", async () => {
    await seedAliceAndBob();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      });
    });

    await assertSucceeds(
      updateDoc(doc(authedDb("alice"), "friendRequests/bob_alice"), {
        status: "declined",
      })
    );
    await assertFails(
      updateDoc(doc(authedDb("alice"), "friendRequests/bob_alice"), {
        status: "accepted",
      })
    );
  });

  it("denies sender setDoc on a declined deterministic id", async () => {
    await seedAliceAndBob();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "declined",
        timestamp: new Date(),
      });
    });

    await assertFails(
      setDoc(doc(authedDb("bob"), "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      })
    );
  });
});

describe("users create and list denials", () => {
  it("denies users create with a non-empty friendIds list", async () => {
    await assertFails(
      setDoc(doc(authedDb("carol"), "users/carol"), {
        displayName: "Carol",
        friendIds: ["alice"],
      })
    );
  });

  it("allows users create with an empty friendIds list", async () => {
    await assertSucceeds(
      setDoc(doc(authedDb("carol"), "users/carol"), {
        displayName: "Carol",
        friendIds: [],
      })
    );
  });

  it("denies listing friendRequests and another user's notifications", async () => {
    await seedAliceAndBob();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "friendRequests/bob_alice"), {
        fromId: "bob",
        fromName: "Bob",
        toId: "alice",
        status: "pending",
        timestamp: new Date(),
      });
      await setDoc(doc(db, "users/alice/notifications/n1"), {
        recipientId: "alice",
        senderId: "bob",
        senderName: "Bob",
        type: "nudge",
        date: new Date(),
        isRead: false,
      });
    });

    await assertFails(getDocs(collection(authedDb("mallory"), "friendRequests")));
    await assertFails(
      getDocs(collection(authedDb("mallory"), "users/alice/notifications"))
    );
  });

  it("denies a stranger deleting someone else's phoneDirectory entry", async () => {
    await seedAliceAndBob();
    await assertFails(
      deleteDoc(doc(authedDb("mallory"), "phoneDirectory/hash_alice"))
    );
  });

  it("does not grant reads when the owner pollutes their own friendIds", async () => {
    await seedAliceAndBob();
    await assertSucceeds(
      setDoc(
        doc(authedDb("alice"), "users/alice"),
        { friendIds: ["mallory"] },
        { merge: true }
      )
    );

    await assertFails(getDoc(doc(authedDb("alice"), "users/mallory")));
    await assertFails(
      getDoc(doc(authedDb("alice"), "users/mallory/availability/2099-01-01"))
    );
  });
});
