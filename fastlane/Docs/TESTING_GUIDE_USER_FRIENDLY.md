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

## First Time Setup (2 minutes)

1. **Open the app**
2. **Sign in** - Tap "Sign in with Apple" (uses your existing Apple ID)
3. **Wait for sync** - The app connects to the internet (takes ~5 seconds)
4. **You're ready!**

---

## Feature 1: Set Your Weekly Schedule

**What it does:** Tell your friends when you're available this week

**How to use it:**
1. Tap the **"My Schedule"** tab (home icon)
2. You'll see 7 days of the week
3. For each day, choose your status by tapping the day:
   - **Free** (green) - Completely available
   - **Afternoon Only** (orange) - Free after 12 PM
   - **Evening Only** (purple) - Free after 6 PM
   - **Busy** (gray) - Not available
   - **Unknown** - Haven't decided yet

4. **That's it!** Your friends can now see your availability

**Tip:** You can change your status anytime during the day. Your friends see updates instantly.

---

## Feature 2: Find Friends by Phone Number

**What it does:** Search for your friends in the app using their phone number

**How to use it:**
1. Tap the **"Find Friends"** tab (person icon)
2. Scroll down to **"Find by Phone Number"**
3. Enter your friend's phone number (example: +1-555-0001)
4. Tap **"Search"**
5. Your friend's profile appears with a button to **"Send Request"**
6. Tap **"Send Request"**
7. Wait for them to accept (they'll get a notification)

**Privacy note:** Phone numbers are hashed and never visible to anyone - only you see the real number.

---

## Feature 3: Accept Friend Requests

**What it does:** When a friend sends you a request, you choose to accept or decline

**How to use it:**
1. Tap the **"Find Friends"** tab
2. Look at the top - you'll see **"Friend Requests"** section
3. See your friend's name and a **"✓ Accept"** or **"✗ Decline"** button
4. Tap **"Accept"** to become friends
5. Once accepted, you'll see each other's schedules

**What happens after you accept:**
- Your availability becomes visible to them
- Their availability becomes visible to you
- You both appear in each other's **"My Trusted Circle"** (friends list)

---

## Feature 4: See Who's Free Today/This Week

**What it does:** Instantly see which friends are available on which days

**How to use it:**
1. Tap the **"Friends Schedule"** tab (calendar icon)
2. You'll see **"Who's free on..."** with 5 buttons for days of the week
3. Each button shows:
   - The day (e.g., "Mon", "Tue", "Wed")
   - A badge with a number (e.g., "2 free") - how many of your friends are completely free
4. Tap a day to highlight it
5. Below, you'll see each friend's availability for that day (color-coded):
   - **Green checkmark** = Free
   - **Gray X** = Busy
   - **Orange** = Afternoon only
   - **Purple** = Evening only

**Tip:** Only "completely free" friends count in the number badge. Partial availability (afternoon/evening only) is shown separately in the list.

---

## Feature 5: Send a Nudge (Say "Hey, I'm Free!")

**What it does:** Send a quick notification to all your free friends on a specific day

**How to use it:**
1. Tap the **"Friends Schedule"** tab
2. Tap a day (e.g., Monday)
3. If there are friends free that day, you'll see **"Nudge all X friends"** button
4. Tap the wave emoji button (👋) in that button
5. Magic! All your free friends get a notification: **"[Your name] nudged you!"**
6. You'll see a success message: **"All 2 friends nudged! 👋"**

**When to use:**
- "Hey, I'm free today and want to hang out"
- "I just became free - who wants to meet up?"
- "Last-minute plans - checking who's available"

**Note:** Only friends who are marked as completely "Free" receive the nudge. If they're "busy" or "afternoon only", they won't get it.

---

## Feature 6: See Notifications (Nudges from Friends)

**What it does:** See when your friends nudge you

**How to use it:**
1. Look at the top-right of the app - you'll see a **bell icon** (🔔)
2. If there's a **red dot**, you have new notifications
3. Tap the bell to open your **Notification Center**
4. You'll see messages like:
   - "[Friend name] nudged you!"
   - "[Friend name] sent you a friend request"
5. Each notification can be tapped to see more details

**Tip:** Your phone will buzz/vibrate when you get a nudge (if notifications are enabled in Settings).

---

## Complete Testing Checklist

If you want to test all features, follow these steps with a friend:

### Setup (5 minutes)
- [ ] Both install the app and sign in
- [ ] Both set your schedule for today (mark both as "Free")

### Phone Search (5 minutes)
- [ ] Person A: Search Person B by phone number
- [ ] Person A: Tap "Send Request"
- [ ] Person B: Open the app and check Friend Requests
- [ ] Person B: Tap "Accept"

### See the Heatmap (3 minutes)
- [ ] Both go to "Friends Schedule" tab
- [ ] Look at "Who's free on..." buttons
- [ ] Both should see "1 free" badge on today's button
- [ ] Tap today's button - you should see each other listed as "Free"

### Send a Nudge (3 minutes)
- [ ] Person A: Select today's day in "Who's free on..."
- [ ] Person A: Tap "Nudge all 1 friends" button
- [ ] Person B: Check notification center (bell icon)
- [ ] Person B: Should see notification from Person A

### Rapid-Fire Test (2 minutes)
- [ ] Person A: Tap the nudge button 3 times rapidly
- [ ] Only the first tap should work (others are ignored)

### Total Time: ~20 minutes

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
A: The request stays pending. You can send another one or ask them to open the app. They'll see it in their "Friend Requests" section.

**Q: Can I see my friend's notifications?**  
A: No - notifications are private. Only you see your own notifications.

**Q: What happens if I mark myself as "Busy" but my friend is "Free"?**  
A: Your friend will see you as "Busy" on the heatmap. They can still nudge you, but only friends marked "Free" get nudged.

**Q: How do I remove a friend?**  
A: Go to "Find Friends" → "My Trusted Circle" → Swipe left on a friend's name → Tap "Remove". They won't see your schedule anymore.

**Q: Can multiple friends have the same phone number?**  
A: No - each phone number is unique. If you search the same number twice, you'll find the same person.

**Q: What if the app crashes?**  
A: Just restart it. Your schedule and friends list are saved. You'll sync with the cloud automatically.

---

## Troubleshooting

**Phone search isn't working?**
- Make sure you entered the number correctly (with country code: +1-555-0001)
- Check that your friend has created an account
- Wait a few seconds and try again

**Friend request didn't appear?**
- Ask your friend to close and reopen the app
- Check that you entered their phone number correctly
- Try pulling down to refresh

**Nudge didn't arrive?**
- Make sure notifications are enabled (Settings → UFree → Notifications)
- Make sure your friend is marked "Free" (not Busy or Afternoon Only)
- Check that you selected a day with free friends

**Heatmap shows "0 free" when friends are available?**
- Make sure your friends set their status to "Free" (not "Afternoon Only" or "Evening Only")
- Those partial statuses don't count in the "X free" badge, only "Free" does

---

## Tips & Tricks

💡 **Set your schedule Sunday night** - Plan your week and let friends see it all week

💡 **Use the heatmap to coordinate plans** - "Let's do dinner on Wednesday when 3 of us are free"

💡 **Check before you nudge** - Tap today's day first to see who's actually free

💡 **Nudge at the right time** - Nudges work best when someone just became free (last-minute hangouts)

💡 **Keep notifications on** - You won't miss a nudge if notifications are enabled

💡 **Share feedback** - If you find a bug or have an idea, tap the Menu and select "Share Feedback"

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
