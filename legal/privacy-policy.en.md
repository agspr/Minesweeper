# Nona Privacy Policy

**Effective:** August 25, 2026
**Last updated:** October 5, 2026

---

## 1. Who We Are

**SENDA LLC** ("we", "us", "our", "Senda") is a limited liability company
organized under the laws of the Commonwealth of Puerto Rico, with a mailing
address at:

> 410 Avenida Montesol, Ste 14 #2078
> Fajardo, Puerto Rico 00738

Senda LLC is responsible for the **Nona** mobile application (the "App"), the
daily sudoku. This Privacy Policy explains what information we collect when you
use the App, how we use it, who we share it with, and what rights you have over
it.

If you have questions about this Policy, write to us at
**support@sendapr.com**.

---

## 2. The Short Version

So that this policy does not require a lawyer to understand, here are the
points that matter most:

- **You can play without an account.** "Play without an account" takes you
  straight to the daily sudoku and to free play, without giving us any personal
  data. An account is needed only for the social features — profile, friends
  and leaderboard — and it is created with Google or Apple; we neither create
  nor store passwords.
- **Nona works entirely offline.** Each day's sudoku travels inside the App; it
  is not downloaded. You can play on a plane, and your progress lives on your
  phone.
- **Your account belongs to Juegos Senda, not just to Nona.** Nona is part of a
  family of games by Senda LLC. Your @username, display name, avatar, country
  and friends list are **the same across all of them**. Your Nona progress, by
  contrast, belongs to Nona alone (see 3.1 and 3.3).
- **Who can see that you play Nona: only your friends.** The App shows your
  friends that you already have Nona, and shows you which of your friends do
  not have it yet, so that you can invite them. That fact — which games in the
  family you have — **can only be looked up by your friends**, not by anyone
  with an account (see 3.4).
- **We do not sell your personal information** to advertisers or to data
  brokers, and we never will.
- **Your games are private.** The detail of each sudoku — what you put in each
  cell, how many mistakes, how long you took — can be read only by your own
  account.
- **We do not store your Google or Apple profile photo.** Your visible identity
  in Nona is the avatar you choose inside the App.
- **With Apple you can hide your email.** If you use "Hide My Email", Apple
  gives us a relay address and we never see your real one.
- **In Apple's settings, Nona appears as "CINCO".** This is not a mistake: the
  games in the family share a single Apple sign-in, and the system lists it
  under the name of the first one (see 3.2).
- **The App is free and shows ads** (Google AdMob), which use your device's
  advertising identifiers. On iOS we ask you first through the system prompt;
  in the European Union and the United Kingdom, Google's consent form is shown
  as well.
- **The "Remove ads" purchase is processed by the store.** The one-time payment
  that removes advertising is handled entirely by the App Store or Google Play:
  we never see your card number or your payment details.
- **We collect usage and crash data** to understand how the App is used and to
  fix what breaks. It is tied to an installation identifier that is **never
  cross-referenced with your account** (see 3.8 and 3.9).
- **Your data lives on Google servers** (Firebase) in the United States region.
  If you write to us from the European Union, the EEA, Switzerland or the
  United Kingdom, that transfer relies on the EU–U.S. Data Privacy Framework
  and on Standard Contractual Clauses (see 5.1).
- **We verify that the App is genuine.** At launch, Google or Apple certify
  that Nona is running on a real, unmodified device. We only receive a yes/no,
  never the device signals themselves (see 3.11).
- **You can leave Nona only, or delete your whole account.** These are two
  different things and both are in the App. The details are in
  [How to delete your account](https://sendapr.com/delete-account/nona/en/).

---

## 3. Information We Collect

### 3.1 Your account information (only if you create one)

**If you play without an account, none of this section applies**: there is no
profile, no email, no user identifier, and your progress lives only on the
phone (see 3.10). Advertising (3.6), usage data (3.8), crash reports (3.9) and
the integrity check (3.11) do still apply, because they do not depend on your
having an account.

An account is optional and exists for the social features. Nona has no
password-based registration: you sign in with **Google** or **Apple**, and the
provider you choose passes us a user identifier and your email address. That
email is administered by Firebase Authentication (Google) as part of the account
system; we do not copy it into our profile database and we do not show it to
other players.

If you sign in with Apple and choose **"Hide My Email"**, Apple generates a
private relay address. In that case we never learn your real email.

**Your account belongs to Juegos Senda, not just to Nona.** If you install
another game in the family and sign in with the same Google or Apple
credentials, it is **the same account and the same profile**: your @username,
display name, avatar, country and friends list are the same across all of them,
and changing them in one game changes them in the others. **Each game's
progress is separate**: your Nona games, streak and points do not appear in any
other game, nor do another game's appear here.

When the account is created we take the name the provider gives us, once, to
seed your display name. From then on that name is yours: you can change it, and
no later sign-in overwrites it. **The provider's profile photo is never stored
at any point.**

### 3.2 "Sign in with Apple" appears as CINCO

If you sign in with Apple, this is worth knowing because it is otherwise
disconcerting: under **Settings → your name → Sign in with Apple**, Nona **does
not appear under its own name, but as "CINCO"**.

The reason is technical and changes nothing about what we do with your data:
the Juegos Senda games share a single application identifier with Apple,
grouped under that of the first game in the family. Apple lists that grouping
under the name of the primary one. It is the same authorization for every game
in the family, which is precisely what makes your account the same across all
of them.

This matters most when deleting your account: if you withdraw the permission
from Apple's Settings, you withdraw it for **the whole family**, not only for
Nona.

### 3.3 Your profile and your Nona progress

We store two different things in Firestore, and the difference matters:

**Your Juegos Senda profile**, shared across every game:

- **@username**: the unique identifier you choose the first time you sign in.
  **You can change it once every 60 days.** The previous one stays reserved to
  you — nobody else can use it, so that nobody can pass themselves off as you —
  but **nobody can find you by it**: searching for it returns no one. When you
  delete your account, all of them are released, the current one and the
  earlier ones.
- **Display name**, **avatar** (one of those the App offers) and **country**,
  if you choose to give it.
- **The date** your account was created.

**Your Nona progress**, stored separately and for this game only:

- **Scores**: current streak, best streak, total points and the weekly and
  monthly aggregates that feed the leaderboard, plus the last day you played.
- **Your daily games**: the result of each day. They are **private**: our
  security rules allow only the account that created them to read them.

We also store, in a **private area only you can read**, your **last activity**,
your **notification token** (see 3.5) and **today's daily, if you have it half
played**: the board as it stands —the digits you placed, your notes, your
mistakes, the playing time, how many moves you have made and whether it is
finished—, so that you can carry on with it on another phone or after signing
out of your account and back in. It is only saved while you are signed in, it is
updated a moment after each move and when you leave the App, and it is **a single
record that each day's game replaces**: no history builds up. Free play games are
not saved to your account.

### 3.4 Friendships, cross-game invitations, blocks and reports

If you use the social features we store:

- **Requests and friendships**: one record per pair of players, with who
  requested it and its status (pending or active).
- **Nudges**: the prompt you send a friend to get them to play.
- **Blocks**: your list of blocked accounts, which is **private** and readable
  only by you. A block prevents that person from sending you requests.
- **Reports**: if you report a player, we keep who is reporting, who is
  reported, the reason you choose —"Offensive name or avatar", "Spam or
  harassment" or "Another reason"— and the date, so that we can review it. **It also reaches
  us by email**, at support@sendapr.com, with both players' @username and
  display name as they stood that day. The reported person **receives no
  notice** and cannot see who reported them. **Reports delete themselves after
  two years**; we delete the email copy ourselves, within the same period.
  They are kept even if either account is deleted: otherwise, deleting an
  account would be enough to put what was reported beyond review.

#### Which games in the family you have, and who can see it

Nona includes a **cross-invitation** feature: in your friends list you can see
**which of your friends do not have Nona yet**, so that you can invite them,
and they can see you the same way from the other games in the family.

To make that work we store, for each game in the family, **whether you have
signed into it with your account**.

**Only your friends can look this up.** Someone who is not your friend cannot
find out which Juegos Senda games you play, even if they find you by your
@username. The same applies to your Nona scores — streak and points: your
friends read them, for the friends leaderboard, and nobody else does.

**Which games you have LEFT is yours alone.** If you leave a game from its
account screen, we store that decision so as not to mark you as one of its
players again, and that record **cannot be read by anyone but you**.

#### What anyone with an account can see

So that people can find you by your @username and send you a request, your
**Juegos Senda profile** — @username, display name, avatar and country — is
readable by anyone with an account in the family. That is what makes it
possible for a friend to look you up before they are one.

One consequence is worth stating plainly: **if you also play CINCO**, because
of how its data was stored from the first day, its score and streak live in
that same shared profile. From there it **can be inferred that you have CINCO**,
and its points seen, without being your friend. **Nona does not work this way**:
its progress lives separately and is closed to your friends. We are working on
correcting that difference in CINCO.

### 3.5 Notifications

If you agree to receive notifications, we store the **messaging token** that
Firebase assigns to your installation of the App. That token identifies the
device so that alerts can be delivered to it (friend requests, acceptances and
nudges) and it renews itself. It is stored in the private area of your profile,
which only you can read.

**We do not ask you for the permission when you open the App.** We ask when it
is needed and makes sense — for example, when you accept a friendship — so that
you know what it is for before deciding. If you decline, no token is stored.

The token is **per account and per game**: if you switch accounts on the same
phone, the previous one is discarded.

### 3.6 Advertising

Nona is free and shows **Google AdMob** ads, as a banner and as a full-screen
ad between games. To serve them, AdMob receives your **device's advertising
identifier** (IDFA on iOS, AAID on Android), your **IP address** and ad events
(whether it was shown, whether you tapped it).

Before requesting the first ad we run two consent checks, in this order:

1. **Google UMP**, the GDPR consent form. In the European Union and the United
   Kingdom the form is shown; in Puerto Rico and the rest of the United States
   it resolves automatically as not required.
2. **App Tracking Transparency** on iOS: the system prompt asking whether you
   allow tracking. If you decline, ads keep working but are not personalized
   with your identifier.

Personalization is applied by Google's own SDK on the basis of that consent; we
do not build advertising profiles ourselves.

If you buy **Remove ads**, the App stops requesting ads: from that moment AdMob
receives nothing from your device on Nona's behalf.

### 3.7 Your purchase ("Remove ads")

Nona offers a single optional purchase: a one-time payment that removes
advertising.

**We neither receive nor store your payment details.** The transaction happens
entirely inside Apple's App Store or Google Play: they charge you, they hold
your payment method and they issue the receipt. We never see your card or your
billing address.

The only thing the App stores is a **yes/no marker on your own device**
indicating that the purchase is active. That marker does not travel to our
servers and is not associated with your profile: your Nona account does not
know whether you have bought it.

As a result, the purchase lives in the **store account** you paid with, not in
your Nona account. If you reinstall the App or get a new phone, use **"Restore
purchases"** on the More screen so that the store confirms it again.

### 3.8 Usage data

We use **Google Analytics for Firebase** to understand how the App is used and
to decide what to improve.

On the one hand, usage data is recorded **automatically**: when the App is first
opened, when a session starts and ends, which screens are visited, whether the
App is updated, and technical device data (model, system version, language and
approximate country by IP).

On the other, we record a limited set of **specific actions**, which are these
and no others:

- Finishing the daily sudoku, recording that day's **difficulty** and **how
  many mistakes** were counted against you (from 0 to 5). We record neither the
  time nor the score.
- Finishing a **free play** puzzle, recording only its difficulty.
- Choosing "Play without an account".
- Signing in, recording only whether it was with Google or with Apple.
- Buying or restoring "Remove ads".
- Sharing a result.
- Sending or accepting a friend request, sending a nudge, and sending an
  invitation to another game in the family.
- On account deletion, whether the revocation of the "Sign in with Apple"
  permission succeeded or failed. We record it because a failure there is not
  visible anywhere else and we need to be able to detect it.

We also store, as a preference for segmenting the analysis, the **colour theme**
and the **language** you choose. Never anything that identifies you.

**What we do NOT record:** the content of your games, your email, your name,
your @username, or any data that identifies you as a person.

This data travels attached to an **installation identifier** generated by
Firebase. That identifier is **not cross-referenced with your account**: the App
never tells the analytics who you are — we do not set a user identifier — so
there is no way to join that data to your profile, your @username or your
games. When you delete your account, that identifier remains unlinked to
anything of yours, because it never was linked.

So that we can analyse it, this data is exported to **BigQuery** (Google
Cloud's data warehouse, inside our own project), where it is stored event by
event and kept for a maximum of **400 days**. We use it to produce aggregate
figures — how many people play, how often — never to follow a particular person
or to build a profile of them.

### 3.9 Crash diagnostics

So that we can fix what breaks we use **Firebase Crashlytics** and **Sentry**.
When the App fails we receive a technical report: device model, operating
system version, App version and the error trace. These reports exist to
diagnose defects, not to profile users, and they contain neither your profile
nor the content of your games.

### 3.10 Data that stays on your phone

Nona is designed to work offline, so **your phone is the primary source of your
progress**: the streak, the points, the state of the game in progress, your
language and colour preferences, and the purchase marker described above are
stored on the device itself.

That data does not leave your phone except when it syncs with your account — if
you have one — and it disappears if you uninstall the App.

### 3.11 Integrity check (App Check)

So that our servers cannot be used from a modified copy of the App or from an
automated script, Nona uses **Firebase App Check**, which relies on **Play
Integrity** (Android) and **App Attest** (iOS).

At launch, the App asks Google or Apple — depending on your system — for a
certificate that it is running on a real device and in a legitimate
installation, and attaches that certificate to its requests to Firebase. To
issue it, Google or Apple evaluate signals from the device and from the
installation itself in accordance with their own privacy policies.

**We do not receive those signals**: only the verdict reaches us (valid or not
valid), which does not identify you, is not stored in your profile and is not
cross-referenced with any other data of yours. This check runs whether you play
with an account or without one.

### 3.12 When you share your result

At the end of a game you can share your result. The App **publishes nothing on
its own**: it prepares a text — the day's difficulty, your points, a row of
squares summarising how many mistakes you made and, if you have one, your
streak — and hands it to your operating system's share menu. You choose who to
send it to and through which app.

That text never passes through our servers, and it **does not reveal the
sudoku**: it includes neither the board nor what you put in each cell, so as
not to spoil it for whoever receives it. It does not include your time either,
because the clock does not affect scoring.

---

## 4. How We Use Your Information

We use the information described above solely to:

- **Run the game**: deliver the daily sudoku, keep count of your mistakes,
  calculate your streak and your points, and preserve them if you change
  phones.
- **Support the social features**: let your friends find you by your @username,
  show the friends leaderboard, deliver nudges, and show you which friends you
  can invite to Nona.
- **Send you notifications** related to those features, if you accepted them.
- **Show ads**, which are what pays for the App's development — and stop
  showing them if you buy "Remove ads".
- **Keep the App standing**: diagnose failures, prevent abuse and review
  reports.
- **Comply with the law** when we are required to.

We do not use your information to make automated decisions producing legal
effects concerning you.

### 4.1 On what legal basis (European Union, EEA and United Kingdom)

If you are in the European Union, the EEA or the United Kingdom, the GDPR
requires us to tell you which legal basis each processing operation rests on.
These are:

| What we use the data for | Legal basis |
|---|---|
| Account, profile, games, leaderboard, friendships, cross-invitations and the notifications you accepted | **Performance of a contract** (Art. 6(1)(b)): these are the features you ask of us by using the App |
| **Personalized** advertising and your device's advertising identifier | **Consent** (Art. 6(1)(a)): the consent you give in Google's UMP form and, on iOS, in the system tracking prompt |
| **Non-personalized** advertising | **Legitimate interests** (Art. 6(1)(f)): financially sustaining a free App |
| Aggregate usage data | **Legitimate interests** (Art. 6(1)(f)): knowing what to improve |
| Crash diagnostics and the integrity check (App Check) | **Legitimate interests** (Art. 6(1)(f)): keeping the App standing, secure and free of abuse |
| Reports: reviewing them, and keeping them for two years even if either account is deleted | **Legitimate interests** (Art. 6(1)(f)): reviewing conduct that breaks the Terms and protecting other players |
| Keeping records the law requires of us | **Legal obligation** (Art. 6(1)(c)) |

Where the basis is **consent**, you can withdraw it at any time without
affecting what was processed beforehand. Where the basis is **legitimate
interests**, you can object by writing to us at support@sendapr.com and we will
consider your case.

---

## 5. Who We Share Your Information With

**We do not sell your personal information.** We share it only with the
providers that make the App work:

| Provider | What for |
|---|---|
| Google Firebase (Authentication, Firestore, Cloud Messaging, Cloud Functions) | Accounts, database, notifications |
| Firebase Crashlytics | Crash reports |
| Sentry | Error monitoring |
| Google AdMob | Advertising |
| Google Analytics for Firebase | Usage data |
| Google BigQuery (Google Cloud) | Storing and querying the usage data, inside our own project |
| Google Play Integrity (via Firebase App Check) | Verifying the App is a legitimate installation, on Android |
| Apple App Attest (via Firebase App Check) | The same, on iOS |
| Zoho Mail | Our support mailbox (support@sendapr.com), where your messages and reports reach us |
| Apple (Sign in with Apple, App Store) | Sign-in, distribution and charging for the purchase on iOS |
| Google Play | Distribution and charging for the purchase on Android |

About the last two rows it is worth being explicit: Apple and Google act as the
**sellers** of the "Remove ads" purchase. They receive your payment details
directly and handle them under their own privacy policies; all we receive from
them is confirmation that the purchase exists.

We may also disclose information if the law requires it, to respond to a valid
request from a competent authority, or to protect the rights and safety of our
users.

### 5.1 Where data is stored, and international transfers

Your data is stored on Google servers in the **United States** region, and the
providers in the table above process it there.

If you are in the **European Union, the European Economic Area, Switzerland or
the United Kingdom**, sending your data to the United States is an
international transfer. It relies on two safeguards, cumulatively:

- The **EU–U.S. Data Privacy Framework** and its United Kingdom and Switzerland
  extensions, to which the providers receiving your data adhere.
- The **Standard Contractual Clauses** approved by the European Commission,
  which form part of the data processing agreements we have signed with those
  providers.

If you would like a copy of the safeguards applicable to your case, ask us at
**support@sendapr.com**.

---

## 6. What Other Players Can See

If you play without an account you appear nowhere: you have no profile for
others to see. What follows applies only if you created an account, and it is
worth stating explicitly because it is the part that most often surprises
people:

- **Visible to anyone with a Juegos Senda account**: your @username, your
  display name, your avatar and your country if you gave it. This is what
  allows a friend to find you before they are one. (If you also play CINCO,
  its points and streak as well — see 3.4.)
- **Visible only to your friends**: that you have Nona, and your Nona scores
  (current streak, best streak, total points and the weekly and monthly ones)
  for the friends leaderboard.
- **Visible only to you**: the detail of each game, your block list, your email
  address, your last activity, your notification token, and which games in the
  family you have left.
- **Visible to the other person**: that you sent them a friend request, a nudge
  or an invitation to Nona.
- **Visible only to us**: reports. The person you report does not see the
  report or who sent it.

If you would rather not appear under your real name, use a different display
name: it is editable at any time from your profile.

---

## 7. Your Rights

At any time, you can:

- **Access** the information we hold about you.
- **Correct** your display name, avatar and country from within the App, and
  your @username once every 60 days. Remember that all four are shared across
  every game in the family.
- **Leave Nona only**, keeping your account, your @username and your friends.
- **Delete your Juegos Senda account** and all associated data, across every
  game in the family. Both options are in the App and are explained in
  [How to delete your account](https://sendapr.com/delete-account/nona/en/).
- **Request a copy** of your data in machine-readable format.
- **Withdraw consent** for personalized advertising, from your operating
  system's privacy settings.
- **Turn off notifications**, from the system settings.

To exercise any of these rights, write to us at **support@sendapr.com**. We
respond within 30 days, and usually much sooner.

### 7.1 Additional rights in the European Union, the EEA and the United Kingdom

If you are in those territories, the GDPR also grants you the rights of
**access, rectification, erasure, restriction of processing, portability and
objection**, and the right to **withdraw your consent** at any time without
affecting the lawfulness of processing carried out beforehand. We do not charge
for handling them.

**And you have the right to lodge a complaint with your country's supervisory
authority** if you believe we are handling your data improperly. For example,
the **Information Commissioner's Office** ([ico.org.uk](https://ico.org.uk)) if
you are in the United Kingdom, the **Agencia Española de Protección de Datos**
([aepd.es](https://www.aepd.es)) if you are in Spain, and the corresponding
authority in other countries. We would appreciate it if you wrote to us first
so we could try to resolve it, but that is neither a requirement nor a
precondition.

---

## 8. Security

Access to the data is governed by security rules on the server itself: each
account can write only its own profile and its own progress, your games and
your block list are unreadable to third parties, which games in the family you
have can be read only by your active friends, and a friendship can only be
accepted by the person who received it. Communications between the App and our
servers travel encrypted over TLS.

No system is invulnerable. Should a breach affecting your personal information
occur, we will notify you through the contact means available and in accordance
with applicable law.

---

## 9. Data Retention

We keep your information while your account is active. If you delete the
account, we delete your profile, your games, your friendships and your
notification token.

In more detail, by type of data:

| Data | How long we keep it |
|---|---|
| Profile, @username, scores, games, friendships, blocks and notification token | While the account is active. On deletion they are erased **immediately** |
| Today's half-played daily | A single record, replaced by the game of the next day you play. Erased **immediately** when you remove Nona from your account or delete it |
| Reports | **Two years** from when they are sent; after that they delete themselves. We delete the copy that reaches us by email ourselves, within the same period. They are kept even if either account is deleted, so that what was reported can be reviewed (see 3.4) |
| Crash reports (Crashlytics and Sentry) | Each service's retention period, **90 days by default**. They contain no part of your profile |
| Usage data | **A maximum of 400 days**, both in Google Analytics for Firebase and in the copy exported to BigQuery. After that period it deletes itself |
| Data stored only on your phone | Until you uninstall the App |
| Records the law requires us to keep | The period set by the applicable rule |

If you leave Nona only, without deleting the account, your Nona progress is
deleted and you stop appearing in its leaderboard; your profile, your @username
and your friends remain intact.

Deleting your account **neither cancels nor refunds the "Remove ads"
purchase**, because that purchase does not live in your account but in your
Apple or Google account. It will remain available through "Restore purchases"
even if you start a new account.

We may keep for longer those records the law obliges us to retain, typically
for accounting or tax reasons.

---

## 10. Children

Nona is not directed at children under 13 and we do not knowingly collect
information from children of that age. If we discover that we have received
information from a child under 13, we will delete it immediately. If you are a
parent or guardian and believe your child has given us information, write to us
at **support@sendapr.com**.

---

## 11. Changes to this Policy

We may update this Policy when the App's features or the applicable law change.
When we do, we will update the "Last updated" date at the top of this document.
If the change is significant, we will tell you inside the App before it takes
effect.

---

## 12. How to Contact Us

**SENDA LLC**
410 Avenida Montesol, Ste 14 #2078
Fajardo, Puerto Rico 00738

**Email:** support@sendapr.com

Use of the App is also governed by our
[Terms of Service](https://sendapr.com/terms/nona/en/).
