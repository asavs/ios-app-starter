# Onboarding research

Two research passes behind the Onboarding module's design, run on 2026-10-19 by a research agent and kept here so the sources can be revisited. The first pass asked what good first-launch onboarding looks like; the second asked what measurably converts to trials, purchases and retention, with a deliberate filter for unsupported claims. Each finding carries a strength label:

- **Strong:** controlled experiment, or large-sample data with the method stated.
- **Moderate:** a named practitioner with numbers, test design partly stated.
- **Weak:** vendor blog without method, anecdote, or a secondhand statistic.

Board tasks that came out of this: `ios-s5.4` (step model, welcome sheet, permission primer), `ios-s5.5` (choice step and tips), `ios-s5.6` (Settings replay row), `ios-s5.7` (paywall step), `ios-s5.8` (commitment step), `ios-s5.9` (plan summary and progress indicator), `ios-s5.10` (social-proof slot), `ios-s5.11` (event hook and holdout flag), `ios-s5.1` (sign-in module). The module's design is described in [modules.md](modules.md#onboarding).

## Part 1: what good onboarding looks like

### Apple's guidance

- Onboarding (HIG): ideally people understand the app by using it; if a flow is needed, make it fast, fun and optional; teach through interaction; consider context-specific tips (TipKit) instead of one flow; let people skip and never re-show, but keep the tutorial reachable from settings or help; postpone non-essential setup; no licensing text or large downloads up front; let people use the app before asking for ratings or purchases; integrate a permission request into onboarding only if the app cannot function without it. https://developer.apple.com/design/human-interface-guidelines/onboarding
- Offering help: tips suit features needing three or fewer actions, one or two sentences, with eligibility rules and a cadence such as once per 24 hours, no promotional content. https://developer.apple.com/design/human-interface-guidelines/offering-help
- Managing accounts: ask for an account only if core functionality requires it; delay sign-in as long as possible; explain benefits on the sign-in view; prefer Sign in with Apple or passkeys; in-app account deletion is mandatory. https://developer.apple.com/design/human-interface-guidelines/managing-accounts
- Sign in with Apple: ask for sign-in only in exchange for value; if an account is required, explain why first; welcome people immediately after; do not ask for optional data up front. https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
- Privacy: avoid launch-time permission requests unless required; a pre-alert screen has exactly one button labelled Continue or Next, never Allow, and no Cancel; purpose strings are active, specific sentences. https://developer.apple.com/design/human-interface-guidelines/privacy
- Materials (iOS 26): Liquid Glass is for the control and navigation layer, not the content layer; use effects sparingly; the clear variant only over rich media. https://developer.apple.com/design/human-interface-guidelines/materials
- Adopting Liquid Glass in SwiftUI (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)` and `.glassProminent`). https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass and https://swiftwithmajid.com/2025/06/10/what-is-new-in-swiftui-after-wwdc25/
- TipKit: iOS 17 and later; `TipGroup` with `.ordered` and `.firstAvailable` from iOS 18; forum reports of popover tip regressions in tab bars and toolbars on iOS 26. https://developer.apple.com/documentation/tipkit/tipgroup and https://developer.apple.com/forums/thread/805796
- There is no system welcome-sheet component; the Stocks and Journal style (icon, feature rows, one Continue) is a convention replicated by open-source packages. https://github.com/lascic/UIOnboarding and https://swiftpackageregistry.com/KC-2001MS/OnboardingUI

### Evidence on tours and tutorials

- **Strong.** Nielsen Norman Group, 70 users, four apps, between-subjects: card-deck tutorials gave no gain in task success (91% versus 94%) or speed, and users rated tasks harder afterwards (SEQ 4.92 versus 5.49, p = 0.047); the same held for coach-mark overlays. Recommendation: spend the effort on the interface and use contextual help. https://www.nngroup.com/articles/mobile-tutorials/ and https://www.nngroup.com/articles/mobile-instructional-overlay/
- **Strong.** Andersen et al., CHI 2012, 45,000 players: tutorials raised play time up to 29% only in the complex game, and nothing in the simple ones. https://grail.cs.washington.edu/projects/game-abtesting/chi2012/
- **Weak.** The widely repeated "three screens or fewer gives over 80% completion, more than five under 60%" is attributed to UXCam but reachable only secondhand. https://trysonar.app/blog/app-onboarding-that-protects-day-1-retention
- **Weak (observational counts).** Lazyweb's capture of 129 flows: median 11 screens; 16% of apps run a personalization quiz averaging 3.9 questions. https://www.lazyweb.com/research/average-onboarding-screens-2026.md and https://experiments.lazyweb.com/research/how-many-apps-use-onboarding-personalization-quiz
- **Weak (talk, no controls).** Analysis of about 1,000 flows: average 25 screens; 23% personalize; Headspace multi-select goals gave about +10% trial conversion; Mural's checklist instead of pop-ups gave about +10% one-week retention; Duolingo shows about 60 screens before account creation but they are interactive. https://sozai.app/transcript/studied-1460-onboarding-flows-findings/index.md

### First launches of well-regarded apps

- Things: no carousel; first launch adds a "Meet Things" tutorial project to the list, recreatable from Settings. https://culturedcode.com/things/support/articles/2803553/
- Bear: no account; three welcome notes in the list, read at the user's pace. https://www.producthunt.com/products/bear/launches/bear-2 and https://goodux.appcues.com/blog/bears-self-paced-onboarding
- Flighty: lands on the live map with an empty-state search; first task is adding a flight; the notification prompt comes in context after that; paywall after the first flight; no sign-in. https://screensdesign.com/apps/flighty-live-flight-tracker/
- Overcast: creates an anonymous sync account silently; email and password are optional later. https://marco.org/2018/04/
- Halide: short feature tour, soft paywall right after, gesture tutorial, learn while using. https://screensdesign.com/showcase/halide-mark-ii-pro-camera and https://lazyweb.com/canvas/companies/halide
- Duolingo: language, goals, placement test, a real first lesson, then the account. https://www.reallygoodux.io/blog/duolingo-user-onboarding
- Headspace (counterexample): sign-in first, carousel, intent question, paywall before any session, nine or ten taps to the first meditation. https://tearthemdown.substack.com/p/headspace

### Anti-patterns

Forced or unskippable tours; re-showing after a skip or on every version bump; sign-up before any value; batch permission prompts at launch; pre-alert screens with "Allow" or a Cancel button; carousels that explain standard controls; paywall or rating request before first value; licensing text; tips with promotional copy; fake progress.

## Part 2: onboarding that converts

Thirty sources read. The Adapty report PDF exceeded the fetch limit, so its own ten-minute summary was used; the UX Planet Blinkist article returned a 403, so growth.design's write-up stands in.

### Where the paywall converts best

- **Strong.** RevenueCat State of Subscription Apps 2026 (115,000 apps, medians and quartiles; RevenueCat sells paywall tooling): 78 to 90% of trial starts happen on install day in every category (Productivity lowest at 78%, Business 89.9%); after day three, under 5% of trials start. Hard-paywall apps convert 10.7% download-to-paid by day 35 versus 2.1% for freemium; freemium conversions trail long (23% after week six). https://www.revenuecat.com/state-of-subscription-apps The 2025 edition (75,000 apps) agrees: 82% day-zero trials, 12.1% versus 2.2%. https://www.revenuecat.com/state-of-subscription-apps-2025
- **Strong-ish (large sample, observational, no confounder control; vendor).** Superwall, 40 million paywall opens, February to May 2026: multi-page onboarding paywalls convert 12.41% versus 9.07% single-page. https://superwall.com/blog/new-postmulti-page-onboarding-paywalls-convert-37-better-than-single-page-heres-why.md
- **Moderate.** Moving the paywall from "after the fifth plant" into onboarding raised Greg's sign-up-to-trial from 3% to 15%; Rootd five-timed revenue by moving it earlier. No test design stated. https://www.revenuecat.com/blog/growth/paywall-placement
- Category differences are only indirect. Productivity has the most delayed trials (22% after day zero) and the most day-zero paid conversions (71.9%). https://www.revenuecat.com/state-of-subscription-apps-2026-productivity Utilities: download-to-trial 6.5% median with wide trial-to-paid variance. https://www.revenuecat.com/state-of-subscription-apps-2026-utilities/ Nothing separates consumer social apps.
- Apple's stance (constraint, not data): the HIG prefers letting people experience the app before prompting for ratings or purchases, while the subscription page says to present subscription benefits during onboarding. Both fit value-first, then a paywall inside onboarding. https://developer.apple.com/design/human-interface-guidelines/onboarding and https://developer.apple.com/app-store/subscriptions/

### Personalization quizzes

- **Strong (randomized, five arms, hurdle model; sample size not published).** Headspace with Irrational Labs: a "perceived fit" quiz that assigned everyone the same Basics course doubled course starts (31% to 63%); a precommitment step (when and where) raised app opens 7.5%; no arm changed active meditation days. The quiz moved activation, not depth of use; trial conversion not reported. https://irrationallabs.com/case-studies/headspace-doubled-course-starts/
- **Moderate.** Lose It! added questions "regardless of the answers"; the trial take rate rose by double digits and kept rising as the flow lengthened until diminishing returns; free-user retention also improved. Adding premium features to onboarding mostly did not help; a configured feature that users later lose did. Sub Club podcast, SVP of Operations, no test details. https://subclub.com/episode/achieving-mission-profit-with-freemium-erin-webster-shaller-and-paul-apollo-lose-it
- **Weak to moderate (vendor, unnamed apps, no sample or significance; Adapty sells an onboarding builder).** Survey plus lesson beat lesson-only (+25% trials); personalization questions beat demos plus social proof (+8.5% trials, +17% paid); shortening a long flow cut conversions 13%. https://adapty.io/blog/how-to-fix-your-onboarding-flow/
- **Strong theory, not mobile.** The idiosyncratic fit heuristic: higher effort raises a program's attractiveness when the user perceives personal fit. Kivetz and Simonson, Journal of Marketing Research 2003. https://business.columbia.edu/sites/default/files-efs/pubfiles/730/Idiosyncratic_Fit_Heuristic.pdf
- Length: no primary data on an optimal count. Observed averages about 25 screens, Duolingo about 60 before sign-up, Noom up to 113 web screens (observational, weak). https://sozai.app/transcript/studied-1460-onboarding-flows-findings/index.md and https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel

### Progress bars, loading screens, social proof, commitment

- Progress bar: **strong for the mechanism, untested in mobile onboarding.** Endowed progress (two pre-punched stamps raised car-wash completion) and the goal gradient (purchase acceleration near the goal), Journal of Consumer Research 2006 and Journal of Marketing Research. https://ideas.repec.org/a/oup/jconrs/v32y2006i4p504-512.html and https://business.columbia.edu/sites/default/files-efs/pubfiles/1200/goalgradient.pdf
- "Building your plan" loading screen: **strong for perceived value only when the work shown is specific** (the labor illusion, Buell and Norton 2011); a generic bar can lower satisfaction. https://pubsonline.informs.org/doi/fpi/10.1287/mnsc.1110.1376 Mobile evidence conflicts: Adapty reports removing a loading screen raised trials 22% in one app and a flow with loading screens winning in another. Unproven either way.
- Social proof: **weak.** Only vendor ranges without method (Superwall "5 to 15%", RocketShip "4 to 9%"). https://superwall.com/blog/how-to-ab-test-a-paywall
- Commitment question: Headspace precommitment (+7.5% opens, strong design) and Lose It!'s loss-aversion setup (moderate). Works for activation; the conversion effect is unmeasured.

### Hard paywall, freemium, trials

- **Strong.** Hard paywall 10.7 to 12.1% day-35 download-to-paid versus 2.1 to 2.2% freemium; refund rate 5.8% versus 3.4%; monthly year-one retention 12.8% versus 9.3% (2025) and "nearly identical" (2026). Longer trials convert better: 17 to 32 days 42.5% median versus 25.5% for four days or less; 55% of three-day-trial cancellations happen on day zero. RevenueCat links above.
- **Moderate.** BoldVoice ($10M ARR) removed the dismiss button and tested a no-exit discount; trial starts rose, refunds "spiked by way more"; they now judge on net revenue after refunds on matured cohorts. https://www.revenuecat.com/blog/growth/anada-lakra-boldvoice-sub-club-podcast-2026
- **Moderate.** Blinkist's transparency paywall (trial timeline, "we'll remind you") gave +23% trial starts and raised notification opt-in from 6% to 74%; A/B claimed, no sample stated. https://growth.design/case-studies/trial-paywall-challenge
- **Weak on definitions (vendor, 11,000 apps).** Adapty: trial users show up to 64% higher LTV; weekly plans with a trial lift day-30 retention from 23% to 42%; annual refund 4.2% versus weekly 2.6%. https://adapty.io/blog/state-of-in-app-subscriptions-2025-in-10-minutes/

### Account creation timing

- **Moderate to strong (named VP, A/B tests at about 100,000 daily actives).** Duolingo: delaying sign-up gave about +20% DAU; replacing a red "Discard my progress" with "Later" and using three soft walls before one hard wall gave +8.2% DAU; hard walls perform significantly worse without soft walls first. https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker
- **Weak counter (no numbers).** Secret Escapes found mandatory sign-in raised LTV and LTV to CAC. https://www.optimizely.com/optimization-glossary/mobile-app-ab-testing
- Web analogue: 19 to 26% of checkout abandoners cite forced account creation (Baymard). https://baymard.com/blog/reduce-cart-abandonment
- Rule: App Store Review 5.1.1(v), "If your app doesn't include significant account-based features, let people use it without a login." https://developer.apple.com/app-store/review/guidelines/

### Notification priming

- **Moderate.** onX pre-permission dialog: baseline 49.7%, "+10.6%" (relative or absolute unclear, design unstated). https://phiture.com/success-stories/onx-inapp/ Cluster: 60% versus a 39% social baseline, 2014 vendor post. https://andrewchen.com/why-people-are-turning-off-push
- **Correlational.** Airship 2017, 63 million users: opted-in users retained 40% longer (iOS retail), but opted-in users who received zero messages retained worse than opt-outs. https://www.airship.com/newsroom/urban-airships-mobile-app-retention-study-for-key-industry-verticals/
- Rules: HIG pre-alert screens have one button labelled Continue or Next and no cancel; App Store Review 5.1.2(i) forbids requiring notifications for functionality. https://developer.apple.com/design/human-interface-guidelines/privacy

### Retention benchmarks

No source separates apps with and without onboarding flows. Blended day-1 about 25%, day-7 about 10 to 12%, day-30 about 4 to 6% (Phiture's aggregation of Statista, AppsFlyer and Adjust, mixed platforms; weak as a target). https://phiture.com/mobilegrowthstack/managing-retention-rate-benchmarks-and-expectations/

### App Store rules that bite

3.1.2(a) bait-and-switch is grounds for removal; 3.1.2(c) describe what the user gets before asking; the subscription page requires the billed amount to be the most prominent price, the trial length and post-trial price stated, and restore purchases present; 5.6 "trick them into making unwanted purchases" is grounds for termination; 5.1.1(iv) no manipulating consent; 3.2.2(x) no forced ratings; 5.6.1 custom review prompts disallowed. https://developer.apple.com/app-store/review/guidelines/

### The slop list

Claims with no traceable primary source, or contradicted by the evidence:

- "Progress bars lift completion 22% (or 16%)", "onboarding raises retention 50%", "90% abandon during onboarding", "users decide in 7 seconds" (the 7-second figure is store-listing dwell time from a five-app AppAgent sample, repurposed).
- "77% churn in 3 days": real but 2015 Android-only Quettra data via Andrew Chen; not iOS, not current. https://andrewchen.com/new-data-shows-why-losing-80-of-your-mobile-users-is-normal-and-that-the-best-apps-do-much-better/
- "Freemium retains better": contradicted by RevenueCat 2025 and 2026.
- "Hard paywall equals more money, full stop": trial starts rise, refunds can rise more (BoldVoice; RevenueCat 5.8% versus 3.4%).
- "Mimo +60% from a multi-screen paywall": secondhand on a podcast, speaker name inconsistent, no design. https://subclub.com/episode/how-to-build-more-successful-paywalls-sylvain-gauchet
- "Apps that A/B test earn 100x" (Adapty): no baseline or method.
- Blinkist "-55% complaints": appears only in secondary write-ups.

### Rules for the module

Default order, and whether a step is on by default:

1. Welcome sheet (shipped): one screen at most. Strong (NN/g; Andersen: tutorials do not help simple apps).
2. Choice step (`ios-s5.5`): on for content, health and education apps, off for utilities; three to six questions; must change at least one visible output (plan, defaults, copy). Headspace strong for activation, Lose It! and Adapty moderate for trials.
3. Commitment step (`ios-s5.8`): when, where or goal; on with the choice step. Headspace strong for opens; conversion unmeasured.
4. Progress indicator (`ios-s5.9`): a step counter on question screens, honest, with no fake head start beyond counting the welcome screen; on when there are three or more question screens. Academic strong, mobile untested.
5. Plan summary (`ios-s5.9`): a result screen that echoes the user's answers into something concrete, with an optional transition under two seconds, never a ten-second fake loader; on with the choice step. Labor illusion strong only if specific.
6. Notification primer (shipped): off by default; on only when the app will send something within seven days. HIG single Continue button; downstream value depends on actually sending (Airship).
7. Paywall step (`ios-s5.7`), host-supplied StoreKit content: on at the end of onboarding for subscription apps, dismissable by default with a hard-paywall flag; two pages, value then offer; trial timeline with the charge date and a reminder promise (Blinkist moderate); billed price most prominent and a restore link; default trial of seven days or more (strong). Strong that day zero is where trials happen.
8. Social-proof slot (`ios-s5.10`): off; real ratings via StoreKit or App Store data only. Weak evidence.
9. Account creation: not an onboarding step. Soft wall after first value with a "Later" affordance, hard wall only after repeated use and only when accounts are core (Duolingo moderate to strong; 5.1.1(v)). The sign-in module (`ios-s5.1`) plugs into the custom slot when an app needs it inside the flow.
10. Tour card and TipKit tips (shipped and `ios-s5.5`): prefer contextual tips over an upfront tour (HIG; NN/g).

Instrument every step with exposure and completion events plus trial start, paid and refund, and ship a holdout flag so each step can be A/B tested (`ios-s5.11`). Peeking daily at p < 0.05 inflates false positives to roughly 25 to 30% (Superwall).

### Open questions: test in your own app

- Quiz length, and whether the answers are theater or real for the product.
- Paywall before versus after the first core action for utilities; the big-sample data is dominated by content and health apps.
- The fake loading screen; the evidence contradicts itself.
- Social-proof placement and whether it beats the trial offer.
- Hard versus soft wall on net revenue after refunds at day 35 or later, not on trial starts.
- Notification primer timing (onboarding versus after the first win) and its effect on day-7 retention, given the app will actually send messages.
- Account-wall timing for apps where accounts are core (Secret Escapes went the other way from Duolingo).
