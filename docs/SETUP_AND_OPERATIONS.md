# Setup, operations and gotchas

Org: `YOUR_ORG_ALIAS`. Primary site: HCP Portal (LWR) `https://YOUR_MYDOMAIN.my.site.com/hcpportalvforcesite/`. Older Aura site `/HCP` ("LSDO - PH - HCP") is kept but its chat widget never rendered. See [ARCHITECTURE.md](ARCHITECTURE.md) for diagrams.

## Deploy order
1. Apex classes, `objects/HCP_Slide_Thumbnail__c`, `lwc/hcpSlideCard`, `lightningTypes/hcpSlideCLT`, `permissionsets`.
2. Agent: `sf agent validate authoring-bundle --api-name HCP_Knowledge_Agent`, then `publish`, then `sf agent activate --api-name HCP_Knowledge_Agent`.
3. Agent user setup (shared user `YOUR_AGENT_USER@example.com`): permission sets `HCP_Knowledge_Agent_Access`,
   `GenieUserEnhancedSecurity`, `LifeSciencesFieldSalesRepresentative`; permission set license `IndustriesLSC4CEPsl`.
4. Run `scripts/apex/publishImmunexisThumbnails.apex` as admin (`sf apex run -f ...`). Re-run whenever slides change.
5. `flows/HCP_Portal_Route_to_Agent`, `messagingChannels/HCP_Portal_Messaging`.
6. Web deployment (one time, NOT idempotent, a second call creates a duplicate):
   `POST /connect/embeddedmessaging/deployment/setup` with name `HCP_Portal_Agent`, deploymentType `Web`, clientVersion `WebV2`,
   hostDomain `YOUR_MYDOMAIN.my.site.com`, messagingChannelId of `HCP_Portal_Messaging`.
   Generated site: `YOUR_ESW_SITE_NAME`, base URL `.../YOUR_ESW_SITE_PATH`.
7. Static resources (`hcpChatInit`, `hcp_*` images), `classes/HcpPortalController`, `lwc/hcpPortalHome`, permission set `HCP_Portal_Access`.
   `hcpChatInit.js` holds the org id `YOUR_ORG_ID`, deployment `HCP_Portal_Agent`, site URL and scrt2URL
   `https://YOUR_MYDOMAIN.my.salesforce-scrt.com`; edit it if the deployment is recreated.
8. Site `DigitalExperienceBundle:site/HCP_Portal1` + `DigitalExperienceConfig:HCP_Portal1` + `Network:HCP Portal` (members `admin`, `HCP User`).
9. Publish: `sf api request rest -o YOUR_ORG_ALIAS -X POST /services/data/v68.0/connect/communities/YOUR_NETWORK_ID/publish --body '{}'`
   (poll `BackgroundOperation` for the returned jobId).
10. Assign `HCP_Portal_Access` to each portal user. Legacy Aura `/HCP`: `ExperienceBundle:LSDO_PH_HCP1` `headMarkup` holds the snippet; publish id `YOUR_AURA_NETWORK_ID`.

## How a turn works
Question -> `slide_search` runs `search_slides` (Data 360 hybrid search over `PresentationPage.Extracted_Text__c`), answers only from slide
text, asks whether to show the slide. "Yes" -> `slide_viewer` calls `show_slide` once; output `c__hcpSlideCLT` renders as `hcpSlideCard`
through the `enhancedWebChat` renderer. The routing flow uses `routingType=Copilot` with a `BotDefinition` setup reference.

## Gotchas found
- Apex actions run as the agent user, not the portal user. Search needs `GenieUserEnhancedSecurity`; `PresentationPage` needs the LSC PSL
  and `LifeSciencesFieldSalesRepresentative`. A permission set granting View All on PresentationLinkedPage fails on this license; use read only.
- The agent user cannot insert `ContentDistribution` (INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY, even `without sharing`), sees its rows
  with all fields blank, and cannot read `ContentVersion`. Hence the admin script + list custom setting. Session-authenticated
  `/sfc/servlet.shepherd` URLs do not work for portal users, which is why public distribution links are used.
- `show_slide` must fail soft (try/catch around the thumbnail) or the model retries the action in a loop.
- Custom settings reject `pluralLabel`. `ContentDistribution.Name` is capped at 100 chars.
- Existing CSP trusted sites already cover `*.my.salesforce-scrt.com` and `*.force.com`. The LWR site CSP blocks inline scripts, so the chat init cannot live in head markup (it is the static resource `hcpChatInit`).
- LWR sites use `DigitalExperienceBundle`/`DigitalExperienceConfig`, not `ExperienceBundle`. `MessagingChannel` must be activated (`IsActive` defaults false). The Network membership gates who can log in.
- CLI: `SFDX_DISABLE_DNS_CHECK=true`; zsh `UID` is read-only; macOS has no `timeout`; `sf api request rest -X POST` needs `--body '{}'`.

## Security notes
- The five thumbnail links are public, unauthenticated, unguessable URLs for the Immunexis slide images only.
- The shared agent user received extra licenses/permissions (step 3). A dedicated agent user and a trimmed
  `LifeSciencesFieldSalesRepresentative` would be least privilege.
- The agent gives no personal medical advice and refers to prescribing information / Medical Information.

## HCP Portal LWR site (`/hcpportal`)

- Site: `DigitalExperienceBundle site/HCP_Portal1` + `DigitalExperienceConfig HCP_Portal1` (template Build Your Own LWR, `AUTHENTICATED`). Live URL: `https://YOUR_MYDOMAIN.my.site.com/hcpportalvforcesite/`.
- Home page is the custom LWC `hcpPortalHome` (hero, nav, stats, Immunexis topic tiles) placed in `sfdc_cms__view/home/content.json`; the theme header/footer are empty.
- Chat: the LWR site CSP blocks inline scripts, so the Embedded Messaging init is in the static resource `hcpChatInit`, loaded by `hcpPortalHome` via `loadScript`. Do not put the snippet in head markup. The `Ask the Agent` buttons call `embeddedservice_bootstrap.utilAPI.launchChat()`.
- Images: static resources `hcp_logo`, `hcp_hero_bg`, `hcp_hero_doctor`, `hcp_agent_band` (resized copies of the generated art). Topic tiles show the real Immunexis slide thumbnails from `HcpPortalController.getSlides()`, which reads `HCP_Slide_Thumbnail__c` (`Title__c` + `Thumbnail_Url__c`). Re-run `scripts/apex/publishImmunexisThumbnails.apex` after slides change.
- Portal users need the `HCP_Portal_Access` permission set (grants `HcpPortalController`); assign it to each HCP portal user.
- Membership: `Network "HCP Portal"` `networkMemberGroups` = `admin`, `HCP User`.
- Publish: `POST /connect/communities/YOUR_NETWORK_ID/publish --body '{}'`.
- The test portal user was switched to the HCP User profile (it lost `/b2benhanced` access).
- Other setup facts: `MessagingChannel` must be activated; thumbnails come from the `HCP_Slide_Thumbnail__c` setting (run `scripts/apex/publishImmunexisThumbnails.apex`).

## Status
- Verified: on the LWR site as the test portal user the chat opens, the agent answers and, after "yes", the slide card with thumbnail renders inline.
- Not yet verified: tile thumbnails after the redesign (the `*.file.force.com` image host may need a CSP trusted site), `run_agent_tests.py`.
- Known issue: Aura `/HCP` chat widget does not render (cause unknown).
- Side effects to remember: the test user lost `/b2benhanced` access when switched to the HCP User profile; the shared agent user got extra permissions; the five thumbnail links are public.
