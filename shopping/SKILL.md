---
name: shopping
description: >
  Cart and merchant discipline for a worker doing a shopping brief — finding
  items, adding to a cart, reading the cart back verbatim, and stopping at the
  money line. Use whenever the brief involves a cart, a checkout, a purchase, an
  order, a merchant, or a price on a real storefront. NOT for reserving a table,
  a flight, or an appointment (that is `booking`), and NOT the place the spend
  itself is approved — approval is the user's, relayed through whoever owns the
  outcome.
---

# Shopping — get it into the cart, prove it, then stop

You can browse, search, compare, and fill a cart. What you cannot do is **spend the
user's money**. The whole craft here is getting the cart exactly right and handing over
a state that somebody else can approve in one look.

## Cart discipline — the read-back IS the evidence

**Add, then read the cart page back verbatim.** A claim without the read-back fails —
what you meant to add is not evidence of what landed.

After every add, go to the cart page and capture, as it actually appears:

- each item's **exact product title** as the merchant writes it,
- **variant** — size, colour, model, edition,
- **quantity**,
- **unit price and line total**, with currency,
- **cart subtotal**, and any shipping / tax line the page shows.

Then compare against the brief line by line. A "close enough" match is a different
product: **the nearest match is not the referent.** A 500ml bottle is not the 1L one, a
renewed unit is not a new one, and a marketplace reseller is not the brand. If the exact
item is not there, that is a finding to report — not a substitution to make quietly.

## Never cross these lines unbidden

Each of these is an irreversible or account-level action, and none of them happens
unless the brief **explicitly** directs that exact action:

- **Never check out.** Never open a payment page, never press the final button.
- **Never save a card**, never store payment details, never opt into one-click.
- **Never create an account.** **Guest carts only** unless the brief names an account
  to use.
- **Never accept an add-on the brief did not ask for** — insurance, extended warranty,
  faster shipping, a subscription, a "members save more" upgrade. **Decline every
  upsell by default.** An accepted upsell is a silent scope change spending the user's
  money.

## Know your stop line before you start

Every money-adjacent run has an explicit stop line. Find it **before** you begin, not
when you are staring at it: *the cart is full and the totals are read back*, *the
sign-in wall*, *the payment page*. **Stopping at the stop line is a success state** —
report it as one, with the cart read-back attached. It is not a failure and it is not a
partial result.

## If the brief genuinely authorises a spend

Then the money rails apply, and they are strict:

- **The final total comes off the merchant's own screen**, at the moment of the action —
  not your arithmetic, not a total you captured ten minutes ago. Prices, shipping and
  tax move.
- **Approval is for an exact amount and an exact final state** — item, variant,
  quantity, total, currency, delivery terms. A standing approval covers precisely what
  it named: a similar item, a larger amount, or a different merchant is a **new**
  approval.
- **Verify what a "free" action costs to undo** before calling it free. Restocking fees,
  non-refundable shipping, and "free cancellation until" windows are real costs.
- **On a decline:** re-check the details, retry **once**, then hand it back with exactly
  what the merchant said. Never try a second card, never split the order, never route
  around it.

## Credentials and identity

A sign-in wall is a **user wall**, not something to solve. Check the browser-creds store
(`aramb_mcp.vault_list_browser_creds`, metadata only — you never read a value), and if
the credential is there let the **browser** type it with `aramb_browser.vault_fill`. If
it is not there, that is a blocker to report, not a reason to create an account. Full
mechanics in `aramb-browser`.

The user's real name, address, phone and card go into a merchant form **only** when the
brief explicitly directs that exact thing for that exact merchant.

## What you report

Close with the observable end state, not the effort:

- the **verbatim cart read-back** (items, variants, quantities, prices, totals),
- the **cart URL** and the browser session / `context_name`, so the state can be picked
  back up rather than rebuilt,
- any **substitution you did not make** and why,
- the **stop line you stopped at**, named,
- anything that looked off — a price that changed mid-flow, a seller that is not the
  brand, a total that does not add up. **Report the smell even when you followed the
  instruction.**

A cart you built and could not prove is worth nothing. A cart you built, read back, and
stopped in front of is the whole job.
