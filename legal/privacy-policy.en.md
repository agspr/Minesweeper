# Nona Privacy Policy

**Effective:** 25 August 2026
**Last updated:** 27 August 2026

---

## 1. Who We Are

**SENDA LLC** ("we", "us", "our", "Senda") is a limited liability company
organised under the laws of the Commonwealth of Puerto Rico, with a mailing
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

So that reading this policy doesn't require a lawyer, here are the points that
matter most:

- **You can play without an account.** "Play without an account" takes you
  straight to the daily sudoku and practice mode without giving us any personal
  data. An account is needed only for the social features — profile, friends
  and leaderboard — and is created with Google or Apple; we never create or
  store passwords.
- **Nona works entirely offline.** Each day's sudoku ships inside the App; it
  isn't downloaded. You can play on a plane, and your progress lives on your
  phone.
- **Your account is a Juegos Senda account, not just a Nona one.** Nona is part
  of a family of games by Senda LLC. Your @username, display name, avatar,
  country and friends list are **the same across all of them**. Your Nona
  progress, by contrast, belongs to Nona alone (see 3.1 and 3.3).
- **Who can see that you play Nona: only your friends.** The App shows your
  friends that you already have Nona, and shows you which of your friends
  don't have it yet, so you can invite them. That fact — which games in the
  family you have — **can only be looked up by your friends**, not by anyone
  with an account (see 3.4).
- **We do not sell your personal information** to advertisers or data brokers,
  and we never will.
- **Your games are private.** The detail of each sudoku — what you put in each
  cell, how many mistakes, how long you took — can only be read by your own
  account.
- **We don't keep your Google or Apple profile photo.** Your visible identity
  in Nona is the avatar you pick inside the App.
- **With Apple you can hide your email.** If you use "Hide My Email", Apple
  gives us a relay address and we never see your real one.
- **In Apple's settings, Nona appears as "CINCO".** This isn't a bug: the
  family's games share one Apple sign-in, and the system lists it under the
  name of the first game (see 3.2).
- **The App is free and shows ads** (Google AdMob), which use your device's
  advertising identifier. On iOS we ask you first through the system prompt; in
  the European Union and the United Kingdom, Google's consent form is shown as
  well.
- **The "Remove ads" purchase is handled by the store.** The one-off payment
  that removes advertising is processed entirely by the App Store or Google
  Play: we never see your card number or payment details.
- **We collect usage and crash data** to understand how the App is used and fix
  what breaks. It is tied to an installation identifier that is **never joined
  to your account** (see 3.8 and 3.9).
- **Your data lives on Google servers** (Firebase) in the United States region.
  If you are writing from the European Union, the EEA, Switzerland or the United
  Kingdom, that transfer relies on the EU–U.S. Data Privacy Framework and on
  Standard Contractual Clauses (see 5.1).
- **We check that the App is genuine.** At launch, Google or Apple certify that
  Nona is running on a real, unmodified device. We only receive a yes or no,
  never the device signals (see 3.11).
- **You can leave Nona alone, or delete your whole account.** These are two
  different things and both are in the App. The details are in
  [How to delete your account](https://sendapr.com/en/delete-account/nona/).

---

## 3. Information We Collect

### 3.1 Your account information (only if you create one)

**If you play without an account, none of this section applies**: there is no
profile, no email, no user identifier, and your progress lives only on your
phone (see 3.10). Advertising (3.6), usage data (3.8), crash reports (3.9) and
the integrity check (3.11) still apply, because they don't depend on your
having an account.

An account is optional and exists for the social features. Nona has no
password-based sign-up: you sign in with **Google** or **Apple**, and whichever
provider you choose gives us a user identifier and your email address. That
email is managed by Firebase Authentication (Google) as part of the account
system; we don't copy it into our profile database and we don't show it to
other players.

If you sign in with Apple and choose **"Hide My Email"**, Apple generates a
private relay address. In that case we never learn your real email.

**Your account is a Juegos Senda account, not just a Nona one.** If you install
another game in the family and sign in with the same Google or Apple account,
it is **the same account and the same profile**: your @username, display name,
avatar, country and friends list are the same across all of them, and changing
them in one game changes them in the others. **Each game's progress is
separate**: your Nona games, streak and points don't appear in any other game,
nor do another game's here.

When you create the account we take the provider's name once, to seed your
display name. From then on that name is yours: you can change it, and no later
sign-in overwrites it. **The provider's profile photograph is never stored at
any point.**

### 3.2 "Sign in with Apple" appears as CINCO

If you sign in with Apple, this is worth knowing because it is otherwise
confusing: under **Settings → your name → Sign in with Apple**, Nona **does not
appear under its own name, but as "CINCO"**.

The reason is technical and changes nothing about what we do with your data:
the Juegos Senda games share a single application identifier with Apple,
grouped under that of the family's first game. Apple lists that grouping under
the main game's name. It is the same authorisation for every game in the
family, which is precisely what makes your account the same across all of them.

This matters most when deleting your account: if you withdraw the permission
from Apple's Settings, you withdraw it for **the whole family**, not just for
Nona.

### 3.3 Your profile and your Nona progress

We store two distinct things in Firestore, and the difference matters:

**Your Juegos Senda profile**, common to every game:

- **@username**: the unique identifier you choose when you first sign in. It is
  permanent: once set it cannot be changed, because it is how other players
  find you.
- **Display name**, **avatar** (one of those the App offers) and **country**,
  if you choose to give it.
- The **date** the account was created.

**Your Nona progress**, stored separately and for this game only:

- **Scores**: current streak, best streak, total points and the weekly and
  monthly totals that feed the leaderboard, plus the last day you played.
- **Your daily games**: each day's result. These are **private**: our security
  rules only allow the account that created them to read them.

We also store, in a **private area only you can read**, your **last activity**
and your **notification token** (see 3.5).

### 3.4 Friendships, cross-game invitations and blocks

If you use the social features we store:

- **Requests and friendships**: one record per pair of players, with who
  requested it and its status (pending or active).
- **Nudges**: the prompt you send a friend to get them to play.
- **Blocks**: your list of blocked accounts, which is **private** and readable
  only by you. A block stops that person sending you requests.
- **Reports**: if you report a player, we receive the report together with the
  reported account's identifier so we can review it.

#### Which family games you have, and who can see it

Nona includes a **cross-invitation** feature: in your friends list you can see
**which of your friends don't have Nona yet**, so you can invite them, and they
can see you the same way from the other games in the family.

To make that work we store, for each game in the family, **whether you have
signed into it with your account**.

**Only your friends can look this up.** Someone who isn't your friend cannot
find out which Juegos Senda games you play, even if they find you by your
@username. The same goes for your Nona scores — streak and points: your friends
read them, for the friends leaderboard, and nobody else.

**Which games you have LEFT is yours alone.** If you leave a game from its
account screen, we store that decision so as not to mark you as one of its
players again, and **nobody but you can read that record**.

#### What anyone with an account can see

So that people can find you by your @username and send you a request, your
**Juegos Senda profile** — @username, display name, avatar and country — is
readable by anyone with an account in the family. That is what makes it
possible for a friend to look you up before they are one.

One consequence should be stated plainly: **if you also play CINCO**, because
of how its data was stored from day one, its score and streak live in that same
shared profile. From this it is **possible to deduce that you have CINCO**, and
to see its points, without being your friend. **Nona does not work this way**:
its progress lives separately and is closed to your friends. We are working on
correcting that difference in CINCO.

### 3.5 Notifications

If you agree to receive notifications, we store the **messaging token** that
Firebase assigns to your installation of the App. That token identifies the
device so we can deliver alerts to it (friend requests, acceptances and nudges)
and it refreshes on its own. It is stored in the private area of your profile,
which only you can read.

**We don't ask for the permission when you open the App.** We ask when it is
needed and makes sense — for example, when you accept a friendship — so that
you know what it is for before deciding. If you decline, no token is stored.

The token is **per account and per game**: if you switch accounts on the same
phone, the previous one is discarded.

### 3.6 Advertising

Nona is free and shows **Google AdMob** ads, as banners and as full-screen ads
between games. To serve them, AdMob receives your **device's advertising
identifier** (IDFA on iOS, AAID on Android), your **IP address** and ad events
(whether it was shown, whether you tapped it).

Before requesting the first ad we run two consent checks, in this order:

1. **Google UMP**, the GDPR consent form. In the European Union and the United
   Kingdom the form is shown; in Puerto Rico and the rest of the United States
   it resolves automatically as not required.
2. **App Tracking Transparency** on iOS: the system prompt asking whether you
   allow tracking. If you decline, ads still work but are not personalised using
   your identifier.

Personalisation is applied by Google's own SDK based on that consent; we do not
build advertising profiles ourselves.

If you buy **Remove ads**, the App stops requesting ads: from that moment AdMob
receives nothing from your device on Nona's behalf.

### 3.7 Your purchase ("Remove ads")

Nona offers a single optional purchase: a one-off payment that removes
advertising.

**We neither receive nor store your payment details.** The transaction happens
entirely inside Apple's App Store or Google Play: they take the payment, they
store your payment method and they issue the receipt. We never see your card or
your billing address.

All the App stores is a **yes/no marker on your own device** indicating that the
purchase is active. That marker never travels to our servers and is not
associated with your profile: your Nona account does not know whether you have
bought it.

As a result, the purchase lives in the **store account** you paid with, not in
your Nona account. If you reinstall the App or get a new phone, use **"Restore
purchases"** on the More screen so the store can confirm it again.

### 3.8 Usage data

We use **Google Analytics for Firebase** to understand how the App is used and
decide what to improve.

On one hand, usage data is recorded **automatically**: when the App is first
opened, when a session starts and ends, which screens are visited, whether the
App is updated, and technical device data (model, system version, language and
approximate country by IP).

On the other, we record a limited set of **specific actions**, which are these
and no others:

- Finishing the daily sudoku, recording that day's **difficulty** and **how
  many mistakes** were counted against you (0 to 5). We record neither the time
  nor the score.
- Finishing a **practice mode** puzzle, recording only its difficulty.
- Choosing "Play without an account".
- Signing in, recording only whether it was with Google or Apple.
- Buying or restoring "Remove ads".
- Sharing a result.
- Sending or accepting a friend request, sending a nudge, and sending an
  invitation to another game in the family.
- When deleting an account, whether revoking the "Sign in with Apple"
  permission succeeded or failed. We record it because a failure there is
  invisible anywhere else and we need to be able to detect it.

We also store, as a preference so we can segment the analysis, the **colour
theme** and the **language** you choose. Never anything that identifies you.

**What we do NOT record:** the contents of your games, your email, your name,
your @username, or any data that identifies you as a person.

This data travels attached to an **installation identifier** generated by
Firebase. That identifier **is not joined to your account**: the App never tells
analytics who you are — we do not set a user identifier — so there is no way to
join that data to your profile, your @username or your games. When you delete
your account, that identifier remains unlinked to anything of yours, because it
never was.

So that it can be analysed, this data is exported to **BigQuery** (Google
Cloud's data warehouse, inside our own project), where it is stored event by
event and kept for a maximum of **400 days**. We use it to produce aggregate
figures — how many people play, how often — never to follow a particular person
or build a profile of them.

### 3.9 Crash diagnostics

So we can fix what breaks, we use **Firebase Crashlytics** and **Sentry**. When
the App fails, a technical report reaches us: device model, operating system
version, App version and the error trace. These reports exist to diagnose
defects, not to profile users, and they contain neither your profile nor the
contents of your games.

### 3.10 Data that stays on your phone

Nona is designed to work offline, so **your phone is the primary source of your
progress**: your streak, points, the state of the game in progress, your
language and colour preferences, and the purchase marker described above are
stored on the device itself.

That data doesn't leave your phone except when it syncs with your account — if
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
joined to any other data of yours. This check runs whether you play with an
account or without one.

### 3.12 When you share your result

When you finish a game you can share your result. The App **publishes nothing
on its own**: it prepares a piece of text — the day's difficulty, your points, a
row of squares summarising how many mistakes you made and, if you have one, your
streak — and hands it to your operating system's share sheet. You choose who to
send it to and through which app.

That text never passes through our servers, and it **does not reveal the
sudoku**: it includes neither the board nor what you put in each cell, so as not
to spoil it for whoever receives it. It also excludes your time, because the
clock does not score.

---

## 4. How We Use Your Information

We use the information described above solely to:

- **Run the game**: deliver your daily sudoku, keep count of your mistakes,
  calculate your streak and points, and preserve them if you change phone.
- **Support the social features**: let your friends find you by your @username,
  show the friends leaderboard, deliver nudges and show you which friends you
  can invite to Nona.
- **Send you notifications** related to those features, if you accepted them.
- **Show ads**, which are what pays for the App's development — and stop showing
  them if you buy "Remove ads".
- **Keep the App standing**: diagnose failures and prevent abuse.
- **Comply with the law** when we are obliged to.

We do not use your information to make automated decisions producing legal
effects concerning you.

### 4.1 Our legal bases (European Union, EEA and United Kingdom)

If you are in the European Union, the EEA or the United Kingdom, the GDPR
requires us to tell you which legal basis each processing activity relies on.
These are:

| What we use the data for | Legal basis |
|---|---|
| Account, profile, games, leaderboard, friendships, cross-invitations and the notifications you accepted | **Performance of a contract** (Art. 6(1)(b)): these are the features you ask of us by using the App |
| **Personalised** advertising and your device's advertising identifier | **Consent** (Art. 6(1)(a)): the consent you give in Google's UMP form and, on iOS, in the system's tracking prompt |
| **Non-personalised** advertising | **Legitimate interests** (Art. 6(1)(f)): sustaining a free App financially |
| Aggregate usage data | **Legitimate interests** (Art. 6(1)(f)): knowing what to improve |
| Crash diagnostics and the integrity check (App Check) | **Legitimate interests** (Art. 6(1)(f)): keeping the App standing, secure and free of abuse |
| Keeping records the law requires of us | **Legal obligation** (Art. 6(1)(c)) |

Where the basis is **consent**, you may withdraw it at any time without
affecting what was processed beforehand. Where the basis is **legitimate
interests**, you may object by writing to support@sendapr.com and we will
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
| Google BigQuery (Google Cloud) | Storing and querying usage data, inside our own project |
| Google Play Integrity (via Firebase App Check) | Checking the App is a legitimate installation, on Android |
| Apple App Attest (via Firebase App Check) | The same, on iOS |
| Apple (Sign in with Apple, App Store) | Sign-in, distribution and collecting payment for the purchase on iOS |
| Google Play | Distribution and collecting payment for the purchase on Android |

About the last two rows it is worth being explicit: Apple and Google act as
**sellers** of the "Remove ads" purchase. They receive your payment data
directly and handle it in accordance with their own privacy policies; we receive
from them only the confirmation that the purchase exists.

We may also disclose information if the law requires it, to respond to a valid
request from a competent authority, or to protect the rights and safety of our
users.

### 5.1 Where data is stored and international transfers

Your data is stored on Google servers in the **United States** region, and the
providers in the table above process it there.

If you are in the **European Union, the European Economic Area, Switzerland or
the United Kingdom**, sending your data to the United States is an international
transfer. It relies on two safeguards, cumulatively:

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
others to see. What follows applies only if you created an account, and it
deserves to be explicit because it is the part that most often surprises people:

- **Visible to anyone with a Juegos Senda account**: your @username, display
  name, avatar and country if you gave one. This is what lets a friend find you
  before they are one. (If you also play CINCO, its points and streak too — see
  3.4.)
- **Visible only to your friends**: that you have Nona, and your Nona scores
  (current streak, best streak, total points and those for the week and month)
  for the friends leaderboard.
- **Visible only to you**: the detail of each game, your block list, your email
  address, your last activity, your notification token and which family games
  you have left.
- **Visible to the other person**: that you sent them a friend request, a nudge
  or an invitation to Nona.

If you would rather not appear under your real name, use a different display
name: it is editable at any time from your profile.

---

## 7. Your Rights

At any time, you can:

- **Access** the information we hold about you.
- **Correct** your display name, avatar and country from within the App.
  Remember that those three are common to every game in the family.
- **Leave Nona only**, keeping your account, your @username and your friends.
- **Delete your Juegos Senda account** and all associated data, across every
  game in the family. Both options are in the App and are explained in
  [How to delete your account](https://sendapr.com/en/delete-account/nona/).
- **Request a copy** of your data in a machine-readable format.
- **Withdraw consent** for personalised advertising, from your operating
  system's privacy settings.
- **Turn off notifications**, from your system settings.

To exercise any of these rights, write to us at **support@sendapr.com**. We
respond within 30 days, and usually much sooner.

### 7.1 Additional rights in the European Union, the EEA and the United Kingdom

If you are in those territories, the GDPR also gives you rights of **access,
rectification, erasure, restriction of processing, portability and objection**,
and the right to **withdraw your consent** at any time without affecting the
lawfulness of processing beforehand. We do not charge for handling them.

**And you have the right to complain to your country's supervisory authority**
if you believe we are handling your data improperly. For example, the
**Information Commissioner's Office** ([ico.org.uk](https://ico.org.uk)) if you
are in the United Kingdom, or the **Agencia Española de Protección de Datos**
([aepd.es](https://www.aepd.es)) if you are in Spain; in other countries, the
relevant authority. We would appreciate you writing to us first so we can try to
resolve it, but that is neither a requirement nor a precondition.

---

## 8. Security

Access to data is governed by security rules on the server itself: each account
can only write its own profile and its own progress, your games and your block
list are unreadable by third parties, which family games you have can be read
only by your active friends, and a friendship can only be accepted by the person
who received it. Communications between the App and our servers travel encrypted
using TLS.

No system is invulnerable. If a breach affecting your personal information were
to occur, we will notify you through the contact means available and in
accordance with applicable law.

---

## 9. Data Retention

We keep your information while your account is active. If you delete the
account, we delete your profile, your games, your friendships and your
notification token.

In more detail, by type of data:

| Data | How long we keep it |
|---|---|
| Profile, @username, scores, games, friendships, blocks and notification token | While the account is active. On deletion they are erased **immediately** |
| Crash reports (Crashlytics and Sentry) | Each service's retention period, **90 days by default**. They contain no profile of yours |
| Usage data | **A maximum of 400 days**, both in Google Analytics for Firebase and in the copy exported to BigQuery. After that period it deletes itself |
| Data stored only on your phone | Until you uninstall the App |
| Records the law obliges us to keep | The period set by the applicable rule |

If you leave Nona alone without deleting your account, your Nona progress is
erased and you stop appearing in its leaderboard; your profile, your @username
and your friends remain intact.

Deleting your account **does not cancel or refund the "Remove ads" purchase**,
because that purchase lives not in your account but in your Apple or Google
account. It will still be available through "Restore purchases" even if you
start a new account.

We may keep for longer those records the law obliges us to retain, typically for
accounting or tax reasons.

---

## 10. Children

Nona is not directed at children under 13 and we do not knowingly collect
information from children of that age. If we discover that we have received
information from a child under 13, we will delete it immediately. If you are a
parent or guardian and believe your child has given us information, write to us
at **support@sendapr.com**.

---

## 11. Changes to This Policy

We may update this Policy when the App's features or the applicable law change.
When we do, we will update the "Last updated" date at the top of the document.
If the change is substantial, we will tell you inside the App before it takes
effect.

---

## 12. How to Contact Us

**SENDA LLC**
410 Avenida Montesol, Ste 14 #2078
Fajardo, Puerto Rico 00738

**Email:** support@sendapr.com

Your use of the App is also governed by our
[Terms of Service](https://sendapr.com/en/terms/nona/).
