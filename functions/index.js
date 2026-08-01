const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

function weekdayLabel(dateString) {
    if (!dateString) return null;
    // Parse YYYY-MM-DD as UTC noon to avoid TZ off-by-one
    const d = new Date(`${dateString}T12:00:00Z`);
    if (Number.isNaN(d.getTime())) return null;
    return d.toLocaleDateString('en-US', { weekday: 'long', timeZone: 'UTC' });
}

/**
 * Triggered when a new notification is added to a user's collection.
 * Sends a generic FCM push notification to protect privacy.
 */
exports.sendPushNotification = functions.firestore
    .document('users/{userId}/notifications/{notificationId}')
    .onCreate(async (snapshot, context) => {
        const notification = snapshot.data();
        const userId = context.params.userId;

        // 1. Get the recipient's FCM token
        const userDoc = await admin.firestore().collection('users').document(userId).get();
        const fcmToken = userDoc.data() ? userDoc.data().fcmToken : null;

        if (!fcmToken) {
            console.log(`No FCM token found for user ${userId}, skipping push.`);
            return null;
        }

        // 2. Prepare payload based on notification type
        let title = "UFree";
        let body = "You have a new message!";
        const day = weekdayLabel(notification.targetDateString);

        if (notification.type === 'nudge') {
            title = "👋 Free soon?";
            body = day
                ? `${notification.senderName} asked if you're free ${day}`
                : `${notification.senderName} sent you a Nudge!`;
        } else if (notification.type === 'nudgeReply') {
            title = "🎉 Hangout update";
            const response = notification.nudgeResponse;
            let verb = "replied";
            if (response === 'imIn') verb = "is in";
            else if (response === 'maybe') verb = "said maybe";
            else if (response === 'busy') verb = "is busy";
            body = day
                ? `${notification.senderName} ${verb} for ${day}`
                : `${notification.senderName} ${verb}`;
        } else if (notification.type === 'friendRequest') {
            title = "🤝 Friend Request";
            body = `${notification.senderName} wants to connect on UFree.`;
        }

        const message = {
            notification: {
                title: title,
                body: body,
            },
            data: {
                type: notification.type || "",
                senderId: notification.senderId || "",
                targetDateString: notification.targetDateString || "",
                nudgeResponse: notification.nudgeResponse || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            token: fcmToken,
        };

        // 3. Send via FCM
        try {
            await admin.messaging().send(message);
            console.log(`Push notification sent to ${userId}`);
        } catch (error) {
            console.error('Error sending push notification:', error);
        }

        return null;
    });

/**
 * Minimal weekend digest: Thu & Fri 11:00 UTC.
 * Generic copy only — no stranger broadcasts.
 */
exports.sendWeekendDigest = functions.pubsub
    .schedule('0 11 * * 4,5')
    .timeZone('UTC')
    .onRun(async () => {
        const usersSnap = await admin.firestore().collection('users').get();
        let sent = 0;

        for (const doc of usersSnap.docs) {
            const data = doc.data() || {};
            const token = data.fcmToken;
            if (!token) continue;

            // Only nudge users who already have at least one friend
            const friendIds = data.friendIds || [];
            if (!Array.isArray(friendIds) || friendIds.length === 0) continue;

            try {
                await admin.messaging().send({
                    notification: {
                        title: "Weekend free?",
                        body: "Mark your days on UFree so friends can find you.",
                    },
                    data: {
                        type: "weekendDigest",
                    },
                    token,
                });
                sent += 1;
            } catch (error) {
                console.error(`Weekend digest failed for ${doc.id}:`, error.message);
            }
        }

        console.log(`Weekend digest sent to ${sent} users`);
        return null;
    });
