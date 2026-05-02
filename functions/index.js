const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

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

        // 2. Prepare generic payload based on notification type
        let title = "UFree";
        let body = "You have a new message!";

        if (notification.type === 'nudge') {
            title = "👋 Nudge!";
            body = `${notification.senderName} sent you a Nudge!`;
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
                type: notification.type,
                senderId: notification.senderId,
                click_action: "FLUTTER_NOTIFICATION_CLICK", // Standard for many libraries
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
