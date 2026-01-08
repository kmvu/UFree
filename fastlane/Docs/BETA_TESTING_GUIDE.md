# How to Test UFree - Complete Feature Guide

**For anyone who wants to try the app and see what it can do (no technical knowledge needed!)**

---

## What is UFree?

UFree helps you and your friends coordinate when you're available. Instead of texting "are you free?", you just set your availability once a week, and your friends can see instantly who's free on which days.

---

## Getting the App

Your friend will send you a link (via email or text) to download UFree from either:
- **TestFlight** (if you have an iPhone) - click the link, install the app
- **Firebase Distribution** (if your friend is testing early) - download via link

---

## First Time Setup (30 seconds)

1. **Open the app**
2. **Enter your name** in the text field (e.g., "Alex")
3. **Tap "Get Started"** - Your account is created instantly and securely

No password, no email, no Apple ID required. Just a name.

---

## Feature 1: Set Your Weekly Schedule

**What it does:** Tell your friends when you're available this week

**How to use it:**
1. Tap the **"Schedule"** tab (calendar icon)
2. You'll see 7 days of the week
3. Tap the Status Banner at the top to cycle through availability statuses:
   - **Free** (green) - Completely available
   - **Afternoon Only** (orange) - Free after 12 PM
   - **Evening Only** (purple) - Free after 6 PM
   - **Busy** (gray) - Not available
   - **Unknown** (light gray) - Haven't decided yet

4. Or tap any individual day card to set that day's status
5. **That's it!** Your friends can now see your availability

**Tip:** You can change your status anytime during the day. Your friends see updates instantly.

---

## Feature 2: Find Friends by Phone Number

**What it does:** Search for your friends in the app using their phone number

**How to use it:**
1. Tap the **"Add Friends"** tab (person.badge.plus icon)
2. Scroll down to the **"Find by Phone Number"** section
3. Enter your friend's phone number (example: +1-555-0001)
4. Tap the magnifying glass search icon
5. Your friend's profile appears with an **"Add"** button
6. Tap **"Add"**
7. They'll get a notification and can accept your request

**Privacy note:** Phone numbers are hashed and never visible to anyone - only you see the real number.

---

## Feature 3: Accept Friend Requests

**What it does:** When a friend sends you a request, you choose to accept or decline

**How to use it:**
1. Tap the **"Add Friends"** tab
2. Look at the **"Friend Requests"** section (appears at the top if you have any)
3. See your friend's name with **"Accept"** (green checkmark) or decline (X) buttons
4. Tap **"Accept"** to become friends
5. Once accepted, you'll see each other's schedules

**What happens after you accept:**
- Your availability becomes visible to them
- Their availability becomes visible to you
- You both appear in each other's **"My Trusted Circle"** section

---

## Feature 4: See Who's Free Today/This Week

**What it does:** Instantly see which friends are available on which days

**How to use it:**
1. Tap the **"Feed"** tab (person.2.fill icon)
2. You'll see **"Who's free on..."** with 5 day buttons
3. Each button shows:
   - The day (e.g., "Mon", "Tue", "Wed")
   - A badge showing how many friends are free (e.g., "2 free")
4. Tap a day to select it
5. Below, you'll see each friend's availability for that day with color indicators:
   - **Green** = Free
   - **Gray** = Busy
   - **Orange** = Afternoon Only
   - **Purple** = Evening Only

**Tip:** Only "completely free" friends count in the "X free" badge. Partial availability (afternoon/evening only) is shown separately in the list.

---

## Feature 5: Send a Nudge (Nudge All)

**What it does:** Send a quick notification to all your free friends on a specific day

**How to use it:**
1. Tap the **"Feed"** tab
2. In the **"Who's free on..."** section, tap a day (e.g., Monday)
3. If there are friends free that day, a **"Nudge all X friends"** button appears
4. Tap the wave icon button (👋) to send the nudge
5. All your free friends get a notification: **"[Your name] nudged you!"**
6. You'll see a success message showing how many friends were nudged

**When to use:**
- "Hey, I just became free today"
- "Who wants to grab lunch?"
- "Last-minute hangout - is anyone available?"

**Note:** Only friends marked as "Free" receive the nudge. Friends marked "Busy" or "Afternoon Only" won't get notified.

---

## Feature 6: See Notifications (Bell Icon)

**What it does:** See when your friends nudge you or send friend requests

**How to use it:**
1. Look at the top-right of the app - you'll see a **bell icon** (🔔)
2. If there's a **red badge with a number**, you have unread notifications
3. Tap the bell to open your notification center
4. You'll see messages like:
   - "[Friend name] nudged you!"
   - "[Friend name] wants to be friends"
5. Each notification shows who sent it and when

**Tip:** Your phone will buzz/vibrate when you get a notification (if notifications are enabled in Settings → UFree → Notifications).

---

## Complete Testing Checklist

If you want to test all features, follow these steps with a friend:

### Setup (2 minutes)
- [ ] Both install the app
- [ ] Both enter your name and tap "Get Started"
- [ ] Both go to **Schedule** tab and set status to "Free" for today

### Phone Search (5 minutes)
- [ ] Person A: Open **Add Friends** tab
- [ ] Person A: In "Find by Phone Number" section, enter Person B's phone number
- [ ] Person A: Tap the search icon (magnifying glass)
- [ ] Person A: Tap "Add" button on Person B's profile
- [ ] Person B: Open the app and go to **Add Friends** tab
- [ ] Person B: Check "Friend Requests" section
- [ ] Person B: Tap "Accept" to become friends

### See Who's Free (Heatmap) (2 minutes)
- [ ] Both go to **Feed** tab
- [ ] Look at **"Who's free on..."** section
- [ ] Both should see "1 free" badge on today's button
- [ ] Tap today's button - you should see each other listed as "Free"

### Send a Nudge (2 minutes)
- [ ] Person A: In the **"Who's free on..."** section, make sure today is selected
- [ ] Person A: Tap the wave icon (👋) button in "Nudge all 1 friends"
- [ ] Person B: Check the bell icon (🔔) - should have a red badge
- [ ] Person B: Tap the bell icon
- [ ] Person B: Should see notification from Person A saying "[Name] nudged you!"

### Rapid-Tap Protection Test (1 minute)
- [ ] Person A: Tap the nudge button 3 times rapidly
- [ ] Only the first tap should send a nudge (others are blocked)
- [ ] You should see "All 1 friends nudged!" message

### Total Time: ~15 minutes

---

## What You'll Notice (Good!)

✅ **Speed** - Everything happens instantly (under 2 seconds)  
✅ **Haptic feedback** - You feel small vibrations when tapping buttons  
✅ **Real-time sync** - Changes appear on both phones without refreshing  
✅ **Privacy** - Phone numbers are hidden (hashed)  
✅ **Smart design** - Only "completely free" friends get nudged (not partial availability)

---

## Common Questions

**Q: What if my friend doesn't respond to the friend request?**  
A: The request stays pending in your **Add Friends** tab. Ask them to check their "Friend Requests" section and tap "Accept".

**Q: Can I see my friend's notifications?**  
A: No - notifications are private. Only you see your own bell icon (🔔) and your own notifications.

**Q: What happens if I mark myself as "Busy" but my friend is "Free"?**  
A: Your friend will see you as "Busy" in the **Feed** tab. Only friends marked "Free" get nudged by the "Nudge all" feature.

**Q: How do I remove a friend?**  
A: Go to **Add Friends** tab → "My Trusted Circle" section → Swipe left on a friend → Tap "Remove". They won't see your schedule anymore.

**Q: Can multiple people have the same phone number?**  
A: No - each phone number is unique. If you search the same number twice, you'll find the same person.

**Q: What if the app crashes?**  
A: Just restart it. Your **Schedule** and friends list are saved automatically. You'll sync with the cloud when you reopen.

---

## Troubleshooting

**Phone search in "Find by Phone Number" isn't working?**
- Make sure you entered the number correctly (with country code: +1-555-0001)
- Check that your friend has created an account (tapped "Get Started" with their name)
- Tap the search icon (magnifying glass) again
- Wait a few seconds and try again

**Friend request in "Friend Requests" section didn't appear?**
- Ask your friend to close and reopen the app
- Check that you entered their phone number correctly
- Both of you must be in the **Add Friends** tab

**Nudge notification didn't arrive?**
- Make sure notifications are enabled (Settings → UFree → Notifications)
- Make sure your friend is marked "Free" (not "Busy" or "Afternoon Only")
- Check that you selected a day in "Who's free on..." and tapped the wave icon
- Your friend must have the app open or notifications enabled

**"Who's free on..." shows "0 free" when friends are available?**
- Make sure your friends set their status to "Free" in the **Schedule** tab
- Statuses like "Afternoon Only" or "Evening Only" don't count in the "X free" badge
- Only "Free" status counts. Those partial statuses show separately in the friends list

---

## Tips & Tricks

💡 **Set your schedule Sunday night** - Use the **Schedule** tab to plan your week. Friends can see your availability all week.

💡 **Use "Who's free on..." to coordinate** - Go to **Feed** tab and look at the day buttons. See "3 free" on Wednesday? Perfect day for dinner!

💡 **Check the heatmap before nudging** - Tap a day in "Who's free on..." to see exactly which friends are free before sending a nudge.

💡 **Nudge at the right time** - Wave icon nudges work best when someone just became free (last-minute hangouts or spontaneous plans).

💡 **Keep notifications enabled** - Go to Settings → UFree → Notifications to stay updated when friends nudge you.

💡 **Add friends from contacts** - In **Add Friends** tab, tap "Sync Contacts to Find Friends" to discover friends based on your phone's contacts (hashed securely).

---

## Need Help?

If something isn't working:
1. **Restart the app** - Close and reopen it
2. **Check your internet** - Make sure you have WiFi or cellular
3. **Wait a few seconds** - Sometimes sync takes time
4. **Restart your phone** - If nothing else works
5. **Share feedback** - In the app, tap Menu → "Share Feedback" to report issues

---

**Enjoy UFree! 🎉**

Made for friends who want to coordinate without the back-and-forth texting.
