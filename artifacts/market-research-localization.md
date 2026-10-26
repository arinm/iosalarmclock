# Punctual: where to localize first (market research, 2026-10-26)

Method: about 28 web searches/fetches, mostly app-store listings, local press, Apple/StatCounter data points and vendor blogs. "Fact" = a source says it. "Inference" = my reasoning. App-store listing claims are developer-written, not verified. Several numbers come from secondary aggregators and are flagged.

## TL;DR

Ranked shortlist (best odds first):

1. **Japan (ja)**: highest holiday density (16 national holidays), iPhone-heavy (~61%), weak English (EF rank 96/123) so an English listing underperforms, and only a handful of tiny holiday-aware iPhone alarm apps. Biggest upside from localizing. Risk: one new AlarmKit-based local rival (Akaru, May 2026) and weak evidence on subscription appetite (lean on the lifetime option).
2. **Germany (de, also reaches AT/CH)**: ~38% iPhone share, strong spenders, and the pain point is real: public holidays differ by Bundesland (9 nationwide, 10-13 per state). The competing iOS 26 alarm app (VariAlarm) has no holiday skip. Risk: high English proficiency means English metadata already partly works, so the localization lift is smaller.
3. **France (fr)**: no French-language iPhone alarm that clearly handles French jours fériés was found; low English reliance; ~33% iPhone share. Evidence is thin (one search), so treat as a promising hypothesis.
4. **Taiwan / Hong Kong (zh-Hant)**: iPhone ~56% in Taiwan, and the make-up-workday (補班) problem is a strong fit for "skip one day, keep tomorrow". But several Chinese-language apps (OK鬧鐘, 咔咔鬧鐘, autoAlarm) already serve it.
5. (Cheap add-on, not a priority) Netherlands / Nordics: very high iPhone share (DK 63%, NO/SE ~56%) and top-tier English, so English metadata already works; localize only if it is nearly free.

Avoid for now: **China mainland** (ICP filing needed for new apps, and 8+ holiday/调休 alarm apps already exist, several already on iOS 26 AlarmKit), **South Korea** (iPhone share ~24%, Samsung has native "skip on holidays", Alarmy's home turf, a local indie AlarmKit app and OK알람 already exist), **Brazil** (iPhone share ~16%, lower ARPU; revisit for pt-BR keywords only).

**Recommended first move:** localize App Store metadata only (name, subtitle, keywords, description, screenshot captions) for **ja, de, fr** first, add zh-Hant second. Do NOT translate the full UI until a metadata test shows impressions and conversion moving. Reasons: metadata is cheap, locales are additive, and it is the only thing that creates local search visibility (inference). Run it as a staggered rollout (ja first, then de/fr) so the other locales act as a rough control.

## Cross-cutting facts

**App Store mechanics**
- App Store Connect now supports metadata in 50 languages, including Japanese, Korean, zh-Hans, zh-Hant, pt-BR, es-MX ([9to5Mac, Mar 2026](https://9to5mac.com/2026/03/31/app-store-connect-adds-11-new-languages-for-localized-app-metadata/)).
- ASO-vendor claim (not verified by me): keywords in a secondary locale are indexed in other storefronts too; for example the US storefront also indexes es-MX, zh-Hans, fr, pt-BR, ko, ru, ar. If true, adding fr/pt-BR/es-MX keywords could also help US search ([Appfigures](https://app.appfigures.com/resources/guides/extend-keyword-list), [AppFollow](https://appfollow.io/blog/app-store-optimization-localization)). Test before relying on it. Vendor sources also claim localization lifts of 26-128% per locale; these have no control groups, treat as marketing.
- Brazilian Portuguese, Spanish (Mexico) and Spanish (Spain) are separate metadata locales.

**iOS 26 adoption (the app requires iOS 26)**
- Apple, 7 June 2026: 79% of all iPhones and 86% of iPhones from the last 4 years ran iOS 26 (iOS 18 was at 82%/88% at the same point) ([MacRumors](https://macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/), [9to5Mac](https://9to5mac.com/2026/06/10/ios-26-adoption-grows-but-still-lags-slightly-behind-ios-18/)). Feb 2026 was 66% ([9to5Mac](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/)).
- No country-level official figure found. StatCounter web-traffic, June 2026 (lower bounds, top-6 versions only): Germany ~66%, Japan ~60%, Brazil ~56% on iOS 26.x ([StatCounter Germany](https://gs.statcounter.com/ios-version-market-share/worldwide/germany), [Japan](https://gs.statcounter.com/ios-version-market-share/worldwide/japan), [Brazil](https://gs.statcounter.com/ios-version-market-share/worldwide/brazil)). Those pages also show a suspicious "iOS 11.0" share (7-16%), likely a user-agent artifact, so treat the numbers as rough.
- Inference: by late October 2026 adoption is higher than June; the requirement removes roughly 15-25% of iPhones everywhere, and competitors that also require iOS 26 (VariAlarm, GT Alarm, Akaru, 极简闹钟, 有时闹钟) face the same cut.

**iPhone share by country (2025, worldpopulationreview table, no primary source named, StatCounter/Kantar listed as inputs; treat as approximate)** ([source](https://worldpopulationreview.com/country-rankings/iphone-market-share-by-country)): Japan 61%, Taiwan 56%, Hong Kong 46%, Germany 38%, Netherlands 38%, France 33%, Italy 32%, Spain 27%, South Korea 24%, China 24%, Brazil 16%, Mexico 25%, Denmark 63%, Norway 56%, Sweden 56%, Finland 31%, US 59%. The same page's body text contradicts its table for some countries (e.g. Japan 61% vs 69%).

**Competitor map (global)**
- **Alarmy** (Delightroom, Korea): store listings in 33 languages; Korean listing shows 4.7 stars, ~110k ratings, free with IAP tiers from KRW 4,800 to 71,000, Lifestyle category (#69 free in Korea), mission-based, no holiday feature mentioned ([App Store KR](https://apps.apple.com/kr/app/alarmy-%EC%95%8C%EB%9E%8C%ED%8C%8C%EC%9D%B4/id1163786766)). Company claims Korea was its #3 download market in 2023 behind US and India, and names Japan and Brazil as focus markets ([DI Today](https://ditoday.com/?p=94689), [VentureSquare](https://www.venturesquare.net/1099873/)). Inference: Alarmy owns the "mission alarm" lane everywhere; Punctual's "skip, don't puzzle" lane is a different one, so Alarmy is a visibility competitor on generic keywords, not a feature competitor.
- A wave of tiny, mostly solo-developer iOS 26 / AlarmKit holiday-skip apps is already live in several markets (listed per market below). Inference: "holiday skip" is no longer an empty lane anywhere; differentiation has to come from the free core quality, the heads-up notification with Skip, calendar auto-skip, and trust (no ads, no account).
- GT Alarm (Gentleflow, iOS 26.0+): auto-skips public holidays, single-day-off, already localized to fr, de, ja, ko, zh-Hans, zh-Hant; $0.99/mo, $5.99/yr, $6.99 lifetime; 1 rating total, so little traction so far ([App Store](https://apps.apple.com/us/app/-/id6752632723)). Note its price points sit well under Punctual's $9.99/yr and $19.99 lifetime.

**Design point that matters for localization (inference from the app description):** Punctual's calendar auto-skip reads the user's own all-day events, so it needs no per-country holiday database; the localization task is mostly telling users which holiday calendar to subscribe to. Caveat found in Korea: Google's "대한민국의 휴일" calendar mixes real holidays with non-holiday observances such as solar terms, which would cause unwanted skips ([Clien thread via search result](https://www.clien.net/service/board/cm_iphonien/19184191)). China/Taiwan add make-up working days (调休/補班) that a "skip when there is an all-day event" rule does not model (a Saturday workday is not an event the app can use to un-skip). That is a feature gap, not just copy.

---

## Japan (ja)

**Demand**
- iPhone ~61% share ([WPR](https://worldpopulationreview.com/country-rankings/iphone-market-share-by-country)); Counterpoint shows iPhones dominating Japan's best-seller list ([Counterpoint](https://www.counterpointresearch.com/en/insights/top-5-smartphone-model-share-8-countries)).
- 16 national holidays after Mountain Day (2016), highest among the G8 at that time ([Malay Mail](https://www.malaymail.com/news/travel/2014/05/24/japan-takes-holidays-to-g8-high-with-mountain-day/674707)). Inference: Golden Week, 振替休日 (substitute holidays) and Monday holidays make "weekday alarm" misfires frequent.
- Pain is documented: Apple's Clock has no holiday off; Japanese guides point to a Shortcuts automation using the "日本の祝日" calendar as the workaround and call it "somewhat complex" ([app-liv](https://app-liv.jp/articles/154556/)).
- English ability is weak (EF EPI 2025 rank 96 of 123, "very low") ([nippon.com](https://www.nippon.com/en/japan-data/h02620/)), so an English-only listing likely converts poorly (inference).
- Japan is a top-3 iOS market by total ecosystem billings ([Apple-commissioned study via MacDailyNews](https://macdailynews.com/2026/06/04/apples-app-store-generated-a-whopping-1-4-trillion-in-sales-in-2025/amp/)), but note IAP revenue there was reported falling in a 2024 Sensor Tower report (secondary).

**Competition**
- **Akaru / アカル (Kurisaku Inc.)**: launched 10 May 2026; weekday/Saturday/holiday rules on a monthly calendar; AlarmKit; iOS 26.2+; free with premium at ¥300/month ([AppBank](https://www.appbank.net/2026/05/12/iphone-application/2997333.php)). The closest direct rival found; no ratings data in the article.
- Alarmy, おこしてME and other mission apps are listed as holiday-capable in a Japanese comparison table (per a search-result summary; I could not open the table). Alarmy's own Korean listing does not mention holidays, so treat this as unverified ([see search result list](https://app-liv.jp/967992/)).
- Generic "目覚まし" mission apps are small: one top-ranking result has 3.3 stars from 7 ratings, English-only listing ([App Store JP](https://apps.apple.com/jp/app/id6737245407)).
- Android-only 「スマートアラーム」 auto-skips Japanese holidays but is not on iPhone ([app-liv](https://app-liv.jp/articles/154556/)).
- Inference: well-known Japanese app reviewers' lists are stale or Android-centric; no established iPhone leader for "holiday-aware alarm" found. Alarmy's stated Japan push is the main long-run threat to generic keywords.

**Monetization**
- Evidence is weak. An Impress poll (n=834, photo/video software, non-representative) preferred one-time purchase 69% to 31% ([DC Watch](https://dc.watch.impress.co.jp/docs/enquete/1664166.html)). A 2024 academic study of 250 Japanese content subscribers notes a preference for ownership ([JIK](https://www.elsevier.es/en-revista-journal-innovation-knowledge-376-pdf-download-S2444569X24001203)). Japanese paywalls tend to be text-heavy with explicit renewal/cancel terms ([Adapty](https://adapty.io/blog/markdown/what-japanese-paywalls-look-like-and-why-western-strategies-wont-work.md)).
- Competitor price anchor: Akaru ¥300/month. Punctual's $1.99/month is roughly ¥300, so parity; the $19.99 lifetime is the natural lead offer in Japan (inference).

**Effort**
- Metadata: ja title/subtitle/keywords (guesses, unverified): 目覚まし, 目覚まし時計, アラーム, 祝日, 祝日 アラーム, スキップ, 休み, 連休, 旅行, 振替休日.
- UI: date format (年月日, 祝日 names), 24h time is common; "Rings in 7h 42m" needs a Japanese phrasing (e.g. あと7時間42分). iOS Calendar already ships a 日本の祝日 calendar users can enable, which feeds calendar auto-skip (per the app-liv guide). Japan's Smartphone Act is pushing external billing but irrelevant here.
- Honest take: ja is the largest upside and the largest translation-quality risk (a wrong tone in an app-store description costs trust).

## Germany (de)

**Demand**
- iPhone ~38% ([WPR](https://worldpopulationreview.com/country-rankings/iphone-market-share-by-country)); all five top-selling models in March 2026 were iPhones ([Counterpoint](https://www.counterpointresearch.com/en/insights/top-5-smartphone-model-share-8-countries)). Germany had the highest iOS 26 web share of the three countries StatCounter I checked (~66% lower bound, June 2026).
- Only 9 holidays are nationwide; states have 10-13 ([Wikipedia](https://en.wikipedia.org/wiki/Public_holidays_in_Germany), [Lingoda](https://www.lingoda.com/blog/en/public-holidays-germany)). Inference: a holiday-aware alarm has to be region-aware, which Punctual's calendar-based approach (user subscribes to their own state's calendar) handles without shipping a database.
- Pain documented: iPhone Clock has no holiday pause; Macwelt notes it also lacks flexible repeats; Focus modes do not silence alarms ([Appgefahren](https://www.appgefahren.de/?p=64553), search summary of Macwelt).
- English proficiency: Germany is #4 of 123 (EF EPI 2025) ([EF](https://www.ef.edu/about-us/press/articles/2025/ef-english-proficiency-index-2025-launched/)). Inference: smaller localization lift than Japan, but German search terms ("Wecker") still drive discovery.

**Competition**
- **VariAlarm** (iOS 26 required): day/week templates, Live Activity; free core, Pro with calendar import at EUR 17.99/year = same as lifetime; no holiday support mentioned; readers asked for holiday handling in the comments ([iphone-ticker, 25 Feb 2026](https://www.iphone-ticker.de/varialarm-wecker-app-unterstuetzt-tages-und-wochenvorlagen-273583/)). It is the main German-language iOS-26 competitor and is not localized by default (inference).
- **Smart Alarm** (2013 launch article): crowd-sourced holiday DB, profiles with vacation days, login needed; current status unknown ([Appgefahren](https://www.appgefahren.de/?p=64553)).
- GT Alarm is localized to German (see above).

**Monetization**
- Adapty's 2026 index (secondary, from a search summary; original not opened) puts Germany/France/Italy/Spain/UK pricing at 1.2x the US baseline ([Adapty benchmark coverage](https://ppc.land/95-of-app-subscription-revenue-goes-to-top-10-adaptys-2026-benchmark-report/)). Western Europe subscription conversion median ~2.0% vs North America 2.6% (secondary, RevenueCat via third party). Inference: a EUR 17.99 lifetime/yearly precedent from VariAlarm suggests Punctual's $9.99/yr and $19.99 lifetime are in the accepted band.

**Effort**
- Metadata (guesses): Wecker, Wecker App, Wecker Feiertage, Urlaub, Schichtdienst, Wecker überspringen, Alarm. Formats: 24h time, dd.mm.yyyy. Ship region guidance: "Feiertage deines Bundeslandes" calendar subscription. Duzen vs Siezen decision (informal "du" is standard for apps).
- DE metadata also covers Austria and Switzerland (de-AT/de-CH share the German locale in App Store Connect; verify).

## France (fr)

**Demand**
- iPhone ~33% ([WPR](https://worldpopulationreview.com/country-rankings/iphone-market-share-by-country)); iPhone 17 led March 2026 sales ([Counterpoint](https://www.counterpointresearch.com/en/insights/top-5-smartphone-model-share-8-countries)). 12 public holidays in 2026 listing, with "ponts" (bridge days) culture (inference).
- Apple Clock has no holiday setting; French guides only advise manual disabling the night before ([Prodigemobile](https://www.prodigemobile.com/tutoriel-apple/desactiver-ou-supprimer-reveil-iphone/)).

**Competition**
- No French-language iPhone alarm clearly covering French holidays was found; closest: Sentarm (English listing, regional calendars, France not confirmed), Off Day (US$4.99, calendars for CN/JP/SG/TH/KR/US, no France), Alaaam, Music Alarm (old, lists France) ([App Store: Sentarm](https://apps.apple.com/ly/app/sentarm/id6747161489), [Alaaam](https://apps.apple.com/mx/app/alaaam/id6747284832)). Evidence is from one search.
- GT Alarm is localized to French.

**Monetization**: no France-specific data found; Adapty 1.2x pricing index only (see Germany).

**Effort**: metadata guesses: réveil, alarme, réveil matin, jours fériés, vacances, ponts, sauter. Formats: 24h, dd/mm/yyyy.

## Taiwan / Hong Kong (zh-Hant)

**Demand**
- iPhone ~56% in Taiwan, ~46% in Hong Kong ([WPR](https://worldpopulationreview.com/country-rankings/iphone-market-share-by-country)); Taiwan is listed at 13 holidays in an older undated table (from a holiday-count search summary; source not opened). Make-up workdays (補班) are routine (inference from the app descriptions below).

**Competition (crowded for a small market)**
- OK鬧鐘 / OK Alarm (Tiger Huang): public holidays, shifts, user-defined overtime/leave days; free + auto-renew premium; users mention ads ([App Store TW](https://apps.apple.com/tw/app/ok%E9%AC%A7%E9%90%98-%E5%9C%8B%E5%AE%9A%E5%81%87%E6%97%A5-%E8%BC%AA%E7%8F%AD%E9%83%BD%E5%A5%BD%E7%94%A8%E7%9A%84%E6%99%BA%E8%83%BD%E8%AA%9E%E9%9F%B3%E6%97%A5%E7%A8%8B%E6%8F%90%E9%86%92/id1477960153)). Korean listing shows 4.8 stars/29 ratings, Pro KRW 1,100/month, 9,900/year, ad removal 25,000 ([App Store KR](https://apps.apple.com/kr/app/ok-%EC%95%8C%EB%9E%8C-%EB%8B%A4%EA%B8%B0%EB%8A%A5-%EC%8A%A4%EB%A7%88%ED%8A%B8-%EC%95%8C%EB%A6%BC/id1477960153)); it supports 8 languages already.
- 咔咔鬧鐘 (subscription, iOS 17.6+), autoAlarm (shortcut-based, forced-ring on make-up workdays, iOS 16+) ([App Store TW](https://apps.apple.com/tw/app/%E5%92%94%E5%92%94%E9%AC%A7%E9%90%98-%E5%85%8D%E8%B2%BB%E7%AF%80%E5%81%87%E6%97%A5%E9%AC%A7%E9%90%98-%E8%87%AA%E5%8B%95%E5%B0%88%E6%B3%A8%E6%A8%A1%E5%BC%8F-%E6%99%BA%E8%83%BD%E5%8A%A9%E7%9C%A0/id6752285870), [autoAlarm](https://apps.apple.com/py/app/autoalarm-system-alarm-helper/id6502572759?l=en-GB)).
- Inference: these already solve holiday skip and (via manual overtime days) 補班; Punctual would compete on polish, no ads, AlarmKit reliability.

**Monetization**: no data found. Note Hong Kong needs zh-Hant with different wording from Taiwan (inference).

**Effort**: metadata guesses (Taiwan): 鬧鐘, 鬧鐘 App, 國定假日, 補班, 輪班, 跳過一天. Same zh-Hant locale serves TW and HK; use TW wording first. Meaningful product gap: 補班 days (Saturday workdays) cannot be expressed by "skip on all-day event" alone.

## South Korea (ko) - low priority

**Demand**
- iPhone ~24% ([WPR](https://worldpopulationreview.com/country-rankings/iphone-market-share-by-country)); Counterpoint shows Samsung's Galaxy S26 Ultra at 43% of March 2026 sales, best iPhone at 6% ([Counterpoint](https://www.counterpointresearch.com/en/insights/top-5-smartphone-model-share-8-countries)). Alarm-app culture is strong (Alarmy's #3 market; 알람몬 claims 27M downloads) ([DI Today](https://ditoday.com/?p=94689), [App Store](https://apps.apple.com/us/app/%EC%95%8C%EB%9E%8C%EB%AA%AC-%EC%95%84%EC%B9%A8%EC%9D%84-%EA%B9%A8%EC%9A%B0%EB%8A%94-%EC%83%88%EB%A1%9C%EC%9A%B4-%EC%95%8C%EB%9E%8C-alarm-clock/id529141346?l=ko)).
- Galaxy has a built-in "skip on holidays" including substitute holidays (대체공휴일) ([Samsung Members, search summary](https://r1.community.samsung.com/t5/%EA%B8%B0%ED%83%80/%EC%95%8C%EB%9E%8C-%EC%95%B1-%EA%B4%80%EB%A0%A8-%EA%B1%B4%EC%9D%98%EC%82%AC%ED%95%AD/m-p/13353467/highlight/true)); iPhone users envy it, which is real demand but a small iPhone base.

**Competition**: Alarmy (home), 알람몬, OK 알람 (see above), plus a solo-dev AlarmKit app "쉬는 날 빼고 알람" that pulls Google Calendar holidays and vacation days, with ads ([Clien](https://www.clien.net/service/board/cm_iphonien/19184191), via search summary). Crowded at the small-base level.

**Monetization**: local price anchors are low (OK 알람 KRW 1,100/month, 9,900/year); Alarmy's tiers up to KRW 71,000. No willingness-to-pay study found.

**Effort**: guesses: 알람, 알람시계, 공휴일 알람, 대체공휴일, 휴가. Watch the calendar caveat (solar terms in Google's Korean holiday calendar).

## China mainland (zh-Hans) - avoid

- Apple began requiring an ICP filing for new apps in the China storefront on 29 Sep 2023; obtaining one is hard without a local company or publisher ([Reuters via DTNext](https://www.dtnext.in/lifestyle/technology/apple-enforces-new-check-on-apps-in-china-as-beijing-tightens-oversight-739784), [Computing](https://computing.co.uk/news/4131589/apple-enforces-chinese-government-licence-requirement)). Rules may have changed since; check Apple developer docs. A workaround is releasing zh-Hans metadata/UI without making the app available in the China storefront (inference; zh-Hans keywords may still index elsewhere per the ASO claim above).
- Competition is already heavy: 有时闹钟 (iOS 26 AlarmKit, ¥6/month, ¥38/year, ¥88 lifetime), 懒人闹钟, 哈基米闹钟, 咔咔闹钟, 极简闹钟 (free, iOS 26+), 指令闹钟, OK闹钟 ([App Store 有时闹钟](https://apps.apple.com/hn/app/%E6%9C%89%E6%97%B6%E9%97%B9%E9%92%9F-%E6%99%BA%E8%83%BD%E8%8A%82%E5%81%87%E6%97%A5%E9%97%B9%E9%92%9F/id6749752316?l=en-GB), [sspai](https://sspai.com/prime/story/shortcuts-holiday-alarm), search summary). Heavy 调休 (make-up workdays) handling is a de-facto requirement.
- Price anchors are far below Punctual's (¥38/year vs $9.99/year), so the monetization fit is poor (inference).

## Brazil (pt-BR) - low priority

- iPhone ~16% ([WPR](https://worldpopulationreview.com/country-rankings/iphone-market-share-by-country)); Sensor Tower lists Brazil among top-3 countries by downloads overall (Q4 2022) ([GameDevReports](https://gamedevreports.substack.com/p/sensor-tower-mobile-market-downloads)) but RevenueCat-derived commentary describes Brazil as lower ARPU/high-volume ([appsops](https://appsops.store/blog/revenuecat-data-local-pricing)).
- Competition: I found no Brazilian alarm app that skips feriados; only English-listing apps (GT Alarm, localized to 7 languages but not pt per its listing) and a generic "Despertador" app ([search results](https://www.accelerated-ideas.com/perguntas-e-respostas/celular/maneira-definir-alarme-iphone-para-sair-feriados-370748-spage.aspx)). Low competition but also low spend.
- Effort: guesses: despertador, alarme, despertador feriados, folga. Cheap to add as metadata only, mainly for US cross-indexing (unverified).

## Spain / LatAm (es), Italy (it), Netherlands, Nordics - not researched in depth

- Only share/English-proficiency data collected: Spain iPhone ~27%, Mexico ~25%, Italy ~32% (EF Italy rank 59/123, moderate English), Netherlands 38% (EF #1), Denmark 63%, Norway 56%, Sweden 56%, Finland 31% ([WPR](https://worldpopulationreview.com/country-rankings/iphone-market-share-by-country), [EF](https://www.ef.edu/about-us/press/articles/2025/ef-english-proficiency-index-2025-launched/)).
- I did not search Spanish/Italian/Dutch/Nordic alarm-app competition, so no ranking claim. Inference: NL/Nordics speak English well, so localization adds little; Spain (14 holidays in 2026, many regional) and Italy (es/it metadata) are plausible later candidates after ja/de/fr results.

---

## What we could not verify

- Country-level iOS 26 adoption from Apple (only StatCounter web traffic, with a suspicious "iOS 11.0" artifact) and any 2026 country split of App Store non-game consumer spend (Sensor Tower/Appfigures country tables are paywalled; Apple-commissioned ecosystem study is not comparable).
- iPhone share by country is from an unsourced aggregator table with internal contradictions; use as rank order only.
- Alarm-app top-chart positions in Utilities/Lifestyle by country (Sensor Tower/data.ai chart data not accessible); only Alarmy's #69 Korea Lifestyle top-free was found.
- Ratings/review counts for Akaru, VariAlarm, 有时闹钟 and most Chinese apps; Japanese holiday-capability of Alarmy and おこしてME beyond a search-result summary.
- Subscription vs one-time willingness to pay per country (only a non-representative Japanese poll and vendor blogs); RevenueCat per-country ARPPU/conversion tables (full report is gated).
- Localization uplift for an alarm app specifically; vendor ranges (26-128%) have no control groups.
- Whether secondary-locale keyword cross-indexing (e.g. fr/pt-BR/es-MX keywords helping US search) still works in 2026.
- China ICP/regulatory status today, and whether releasing zh-Hans outside the China storefront is allowed in practice.
- Current availability/pricing of Smart Alarm (iOS, 2013 article) and Sentarm/Alaaam holiday coverage for France/Brazil.
- Spain/LatAm, Italy, Netherlands and Nordics competition (not searched).
