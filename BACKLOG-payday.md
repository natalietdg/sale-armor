# Payday setting + "start blocking now?" nudge

**Captured 2026-08-24 from Natalie, not yet designed or built.** Written down because the idea
was nearly lost once already. Nothing in this file has been checked against the code.

## The ask, in her words

> add a payday setting, and notification like "wanna start blocking now?"

## What it seems to mean

A payday is the day impulse spending is most likely, so the app would learn when money lands and
offer to start a blocking session around it — asking rather than switching itself on.

## Two notifications, not one — she settled this

> or maybe a notification "blocked for Payday" smth like that, if its already setup

So the notification depends on whether payday blocking is configured, and the earlier
offer-versus-automatic question answers itself:

| state | notification | what it is |
|---|---|---|
| payday known, blocking **not** set up | "Wanna start blocking now?" | an **offer** — a tap starts a session |
| payday known, blocking **already** set up | "Blocked for Payday" | a **status notice** — it already happened |

That is a better design than either alone. The offer never nags someone who has already decided,
and the status notice tells the person who set it up that the thing they asked for is running,
which is the difference between a tool that feels reliable and one that feels silent.

The second one is a *statement*, so it must be true when it fires. It should be sent by whatever
actually turns blocking on, not by a schedule that assumes it worked.

## Open questions to settle before building

- **Payday shape.** Fixed day of month, last working day, fortnightly, or twice-monthly? Malaysian
  payroll is commonly last working day, which is not a fixed date.
- **When does the nudge fire** — payday morning, payday evening, the night before?
- **How long is the offered session**, and does it end by itself?
- **What happens if it is declined** — silence until next payday, or a softer follow-up?
- **Permission.** Does the app already ask for notification authorisation, and what does it
  currently send? A blocking app that starts nagging is the thing users delete.

## Before touching this

Its own session — `cd ~/sale-armor` and start fresh. It was raised in the middle of the
BaoBeiTalk App Store submission and deliberately not built there.
