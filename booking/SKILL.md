---
name: booking
description: >
  How a worker fills a reservation or appointment flow to its REVIEW state,
  captures the read-back, and STOPS. Use whenever the brief involves booking or
  reserving anything real — a table, an appointment, a flight, a hotel, a
  viewing, a slot. NOT for carts and merchandise (that is `shopping`), and NOT
  the place a booking is confirmed — confirming is a hard-to-undo commitment that
  belongs to the user.
---

# Booking — fill it to review, prove it, stop there

A real reservation is a **hard-to-undo external commitment**: someone holds a table, a
seat, a slot, and a cancellation costs somebody something. So the job has a fixed shape
and a fixed ending.

> **Fill to the final REVIEW state. Capture the verbatim read-back. STOP. Escalate.**

Pressing confirm is not your call, ever, unless the brief explicitly directs that exact
booking. A free slot is not permission. A finished search is not permission. **A
reversible-by-cancellation booking is not free** — it notifies people, it occupies
someone else's calendar, and undoing it is real work.

## Fill it properly

- **Use the identity the brief names.** Never the user's real name, phone, email or card
  unless the brief explicitly directs it for this exact booking.
- **Read back every field you filled, before you advance a step.** Open the field and
  read what is actually in it. What you meant to type is not evidence of what landed —
  autocompletes overwrite, date pickers snap to a different day, phone fields strip
  digits.
- **Dates, times and time zones get checked twice.** Most booking errors are a correct
  value in the wrong frame: the venue's local time vs. the user's, a 24h field read as
  12h, a date that rolled over midnight.
- **Decline every add-on the brief did not ask for** — insurance, a seat upgrade, a
  premium slot, a subscription. An accepted upsell is a silent scope change.

## The review capture

At the review / confirm screen — the last page before the commitment — capture it
**verbatim, as the venue states it**, because this is what the user will be approving:

- **venue / provider**, exactly as named,
- **date and time, with the time zone**,
- **party size / duration / seats / room type**,
- **the name the booking is under**,
- **the total, in its currency**, including fees,
- **the cancellation terms and the deadline**, word for word,
- anything the page says is **non-refundable**.

Then stop. Do not press the button. Report the review state with the session /
`context_name` so the flow can be resumed and confirmed without redoing it.

**Stopping here is a success state.** Report it as the outcome it is, not as a
half-finished job.

## Ambiguity is a question, not a guess

If the brief does not settle which slot, which date reading, or which of two venues —
**the deliverable is the question, with the work already done behind it.** Do not
convert completed research into a commitment because one option looked obviously best.

And when you *must* pick one reading of an ambiguous date or name to make progress:
state the pick, and attach the already-computed answer for the other reading. A
correction should cost one word, not a whole re-run.

## Re-verify at fire time, not at draft time

If you are resumed later to complete a booking that was approved earlier, **re-open the
page and re-read the state before acting.** Approvals go stale: prices move, the slot
gets taken, the cancellation window shifts, the cart expires. Confirm the live state
still matches what was approved. If it does not, that is a blocker — report the delta,
do not proceed on the old approval.

## Walls

- A **sign-in wall** is a user wall: check `aramb_mcp.vault_list_browser_creds`, let the
  browser fill with `aramb_browser.vault_fill` if the credential exists, otherwise report
  the blocker. Never create an account to get past it. (`aramb-browser` has the detail.)
- A **captcha, phone verification, or security challenge** is a **STOP**. Document
  precisely what you saw and report it. Never route around it.
- An **OTP or confirmation code** the user must supply is a blocker; name exactly what
  you need and where it will arrive.

## What you report

The venue's own words for the whole review state, the URL and session, what you filled
and with which identity, the stop line you stopped at, and the one decision the user
now has to make. Plus anything that smelled wrong even though you followed the brief —
a price that jumped, terms that changed, a venue that does not match the name given.
