# Permission Set Patches — Phase 5A.1

These are the `<fieldPermissions>` entries to merge into the existing permission set XML files in your `force-app/main/default/permissionsets/` directory. Add each block inside the existing `<PermissionSet>` root element, alphabetically among other fieldPermissions.

---

## ULBC_Full_Access.permissionset-meta.xml

```xml
<fieldPermissions>
    <editable>true</editable>
    <field>Contact.ULBC_Stripe_Customer_ID__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>false</editable>
    <field>Contact.ULBC_Donation_Link__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>true</editable>
    <field>CampaignMember.ULBC_Stripe_Payment_ID__c</field>
    <readable>true</readable>
</fieldPermissions>
```

Note: `ULBC_Donation_Link__c` is a formula field — `editable` MUST be `false`. SFDX will reject the deployment if this is set to `true` for a formula field.

---

## ULBC_Finance.permissionset-meta.xml

```xml
<fieldPermissions>
    <editable>true</editable>
    <field>Contact.ULBC_Stripe_Customer_ID__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>false</editable>
    <field>Contact.ULBC_Donation_Link__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>true</editable>
    <field>CampaignMember.ULBC_Stripe_Payment_ID__c</field>
    <readable>true</readable>
</fieldPermissions>
```

---

## ULBC_Fundraiser.permissionset-meta.xml

```xml
<fieldPermissions>
    <editable>true</editable>
    <field>Contact.ULBC_Stripe_Customer_ID__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>false</editable>
    <field>Contact.ULBC_Donation_Link__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>true</editable>
    <field>CampaignMember.ULBC_Stripe_Payment_ID__c</field>
    <readable>true</readable>
</fieldPermissions>
```

---

## ULBC_Event_Organiser.permissionset-meta.xml

Per Decision 5.10: Event Organiser gets R/W on the CampaignMember field ONLY. Does NOT get the Contact Stripe Customer ID (donor info — restricted) or Donation Link (donor info — restricted).

```xml
<fieldPermissions>
    <editable>true</editable>
    <field>CampaignMember.ULBC_Stripe_Payment_ID__c</field>
    <readable>true</readable>
</fieldPermissions>
```

---

## Object permissions for the new Custom Setting

`ULBC_Stripe_Settings__c` is a Hierarchy custom setting — it does NOT need object-level permissions in perm sets. Apex code accesses it via `ULBC_Stripe_Settings__c.getOrgDefaults()` regardless of running user. No perm set update required.
