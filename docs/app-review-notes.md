---
title: App Review notes (draft)
---

# App Review notes: Friends and Groups

Paste the text below into App Store Connect, App Review Information, Notes.

## Text for the review notes

MOTI has an optional "Friends and groups" feature (Study tab, "Friends & groups"). It lets a user see a friend's nickname, whether they are studying now, and their study time today. There is no developer server: data is stored in the app's CloudKit public database (iCloud.com.donghyeon.moti) and the feature needs an iCloud account, not an app login.

User-generated content (guideline 1.2):
- The only user content is a nickname (max 12 characters) and a group name (max 20 characters). There is no chat, photo or free text.
- Terms: the first-use screen shows "Friends only see your nickname and study time" and links to the Terms of Use and Privacy Policy. Starting the feature means agreeing to them.
- Filter: obvious profanity is rejected in nicknames and group names.
- Report: every person row (friends list and group member list) has a "..." menu with "Report" (reasons: inappropriate name, harassment, spam, other). A report is stored as a MotiReport record that only the developer can read in CloudKit Console, and the reported person is hidden immediately on the reporter's device.
- Block: "Block" in the same menu; blocked people are removed from friends and groups on that device. Settings, "Blocked people", can undo it.
- Hide: Settings, "Show my study status" off, shows only the nickname to others.
- Delete: Settings, "Turn off Friends and delete my info" deletes the user's public profile, group membership records and groups they created.
- Only people who know a user's friend code can find the user. The code can be regenerated in Settings.
- The developer reviews reports and can remove abusive profiles in CloudKit Console within 24 hours (contact: 5pal1ori@gmail.com).

## How to test (two devices or two iCloud accounts are needed)

1. On device A and device B, sign in to iCloud (Settings), open MOTI, continue as guest or sign in, go to the Study tab and tap "Friends & groups".
2. Enter a nickname and tap "Start". The screen shows "My friend code" (8 characters, for example K7QM-3XPR).
3. On device B, tap "Add friend" and enter A's code. A appears in B's list with today's study time. Starting the study timer on A makes "Studying · N min" appear for A on B within about a minute.
4. Tap "..." on a person: Report, Block, Remove friend.
5. Groups tab: "Create group" on A, then on B "Join with code" and enter the 6-character invite code shown in the group screen. Members are listed with today's time; the segmented control switches to this week's ranking.
6. Settings (gear icon): nickname, "Show my study status", "Regenerate friend code", "Blocked people", "Turn off Friends and delete my info".

A reviewer without a second device can still open the screens, create a group and see the report/block/delete controls; the friends list stays empty until a friend code is added.
