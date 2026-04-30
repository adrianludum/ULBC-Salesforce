# Xero orphan donations — what to do when you get a notification

**For**: Martin Peel (Finance) — and anyone else added to the orphan reviewer list later.

## What's an "orphan"?

Every night at 02:00 UTC, Salesforce pulls the previous day's `RECEIVE` bank transactions from Xero and creates one Opportunity per transaction. It tries to match the Xero contact to a Salesforce Contact by **Trust ID** (= Xero contact's AccountNumber).

When it can't find a match, it still creates the Opportunity — but **without a Primary Contact**. That's an orphan. The donation isn't lost; it just isn't attributed to a donor yet.

## How you'll find out

You'll get notified two ways. Either is enough — they're both pointing at the same Opportunity.

1. **Salesforce notification (bell + mobile)** — fires immediately when the orphan is created. Title: "Unmatched Xero deposit". Tap/click → opens the Opportunity.
2. **Email** — once the master switch is on, you also receive a digest at the email address `adminulbh@gmail.com`. One email per import page summarising every orphan in that run, with clickable links and the donor info Xero provided (name, AccountNumber, email).

## What to do — three scenarios

### 1. You recognise the donor

- Open the Opportunity (link in the notification or email).
- In the **Primary Contact** field, set it to the right Salesforce Contact and save.
- That's it. The Opportunity is no longer an orphan. The donor's giving history updates automatically.
- **Bonus**: if the Salesforce Contact's **Trust ID** field is blank, fill it in too (use the AccountNumber from the email/Xero). That stops the same donor showing up as an orphan next month.

### 2. You don't recognise the donor

- Leave the Opportunity unassigned for now.
- Open Chatter on the Opportunity and add a comment for Adrian / the fundraiser describing what you know (donor name from Xero, amount, date).
- Once the donor's identity is confirmed, follow scenario 1.

### 3. The donor doesn't exist in Salesforce yet

- Create a new Contact in Salesforce with the donor's details and a Trust ID.
- Then follow scenario 1 to set the Primary Contact on the orphan.

## Where to find all current orphans

Open the **Opportunities** tab → list view: filter on `Source = Xero Import` AND `Primary Contact = blank`. (Adrian: pin a saved list view called "Xero Orphans" for Martin if not already done.)

## Who to ping if something looks wrong

- Notifications stopped arriving / nothing fires when you know orphans are appearing → Adrian.
- The Opportunity link in the email or notification opens the wrong record → Adrian.
- You want to add another reviewer's email so you're not the only recipient → Adrian (one Custom Setting field edit).

## Master switch

The email channel can be turned on/off without code changes via Setup → Custom Settings → ULBC Xero Settings → `Orphan Notifications Enabled`. The Salesforce bell notification is controlled separately by the Flow `Xero_Orphan_Alert` (Setup → Flows). Off-by-default for email until first smoke test passes.
