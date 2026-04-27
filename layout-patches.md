# Page Layout Patches — Phase 5A.1

## Contact Layout

### New section: "Stripe Integration"
Position: AFTER "Donor Tier" section, BEFORE "System Information"

Two-column layout, fields:
- Column 1: `ULBC_Stripe_Customer_ID__c` (read-only in UI — webhook-populated)
- Column 2: `ULBC_Donation_Link__c` (read-only — formula field, always read-only)

Both fields visible to: Admin, Fundraiser, Finance (FLS-controlled by perm sets above).
Both fields hidden from: Event Organiser, Coach, Boathouse Manager (no FLS read).

### XML to merge into existing Contact-Layout-meta.xml

Add this `<layoutSections>` block in the appropriate position within the existing `<Layout>` root:

```xml
<layoutSections>
    <customLabel>false</customLabel>
    <detailHeading>true</detailHeading>
    <editHeading>true</editHeading>
    <label>Stripe Integration</label>
    <layoutColumns>
        <layoutItems>
            <behavior>Readonly</behavior>
            <field>ULBC_Stripe_Customer_ID__c</field>
        </layoutItems>
    </layoutColumns>
    <layoutColumns>
        <layoutItems>
            <behavior>Readonly</behavior>
            <field>ULBC_Donation_Link__c</field>
        </layoutItems>
    </layoutColumns>
    <style>TwoColumnsTopToBottom</style>
</layoutSections>
```

Note: `behavior` is `Readonly` for both. The Stripe Customer ID is conceptually editable (Decision 5.10 grants R/W to perm sets) but no human should ever type it — webhook only. Setting layout behavior to Readonly makes the UI honest about that.

---

## CampaignMember Layout

### New section: "Payment"
Position: AFTER "Information" (default first section), BEFORE "System Information"

Single-column, single field:
- `ULBC_Stripe_Payment_ID__c` (read-only in UI — webhook-populated)

Visible to: Admin, Fundraiser, Finance, Event Organiser.

### XML to merge into existing CampaignMember-Layout-meta.xml

```xml
<layoutSections>
    <customLabel>false</customLabel>
    <detailHeading>true</detailHeading>
    <editHeading>true</editHeading>
    <label>Payment</label>
    <layoutColumns>
        <layoutItems>
            <behavior>Readonly</behavior>
            <field>ULBC_Stripe_Payment_ID__c</field>
        </layoutItems>
    </layoutColumns>
    <style>OneColumn</style>
</layoutSections>
```

---

## A note on the layouts directory

If you don't already have `Contact-Layout.layout-meta.xml` and `CampaignMember-Layout.layout-meta.xml` checked into your SFDX project, you need to retrieve them first:

```bash
sf project retrieve start --metadata Layout:Contact-Layout --target-org ulbc
sf project retrieve start --metadata "Layout:Contact Layout" --target-org ulbc
```

The exact layout name depends on the org — Contact's default page layout is usually called "Contact Layout" with a space. Check what's actually in your org with:

```bash
sf org list metadata --metadata-type Layout --target-org ulbc | grep -i contact
sf org list metadata --metadata-type Layout --target-org ulbc | grep -i campaign
```

Then retrieve, edit (merging in the section above), and deploy.
