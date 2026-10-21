# Architecture

## 1. Components

```mermaid
flowchart TB
    subgraph Browser
        U([HCP user])
    end

    subgraph Site["HCP Portal (LWR, AUTHENTICATED)"]
        Home[hcpPortalHome LWC<br/>nav, hero, tiles, agent band]
        Init[static resource hcpChatInit<br/>loads bootstrap.min.js, calls init]
        Img[static resources<br/>hcp_logo, hcp_hero_bg,<br/>hcp_hero_doctor, hcp_agent_band]
        Ctl[HcpPortalController.getSlides]
    end

    subgraph Chat["Embedded Messaging (MIAW)"]
        ESC[EmbeddedServiceConfig<br/>HCP_Portal_Agent, Web]
        MC[MessagingChannel<br/>HCP_Portal_Messaging, active]
        Flow[Flow HCP_Portal_Route_to_Agent<br/>routeWork, routingType Copilot]
    end

    subgraph AgentSide["Agentforce"]
        Agent[HCP_Knowledge_Agent<br/>Agent Script, AiAuthoringBundle]
        A1[ContentSearchAction<br/>search_slides]
        A2[HcpShowSlideAction<br/>show_slide]
        CLT[Custom Lightning Type hcpSlideCLT]
        Card[hcpSlideCard LWC]
    end

    subgraph Data
        PP[(PresentationPage<br/>Extracted_Text__c)]
        CS[(HCP_Slide_Thumbnail__c<br/>Title__c, Thumbnail_Url__c)]
        CD[(ContentDistribution<br/>public image links)]
    end

    U --> Home
    Home --> Img
    Home --> Init --> ESC
    Home --> Ctl --> CS
    ESC --> MC --> Flow --> Agent
    Agent --> A1 --> PP
    Agent --> A2 --> CS
    A2 --> CLT --> Card
    CS -. url points to .-> CD
    Card -. img .-> CD
```

## 2. One chat turn

The "ask, then yes" pattern: the first message only searches and answers from slide text, then asks before showing a slide.

```mermaid
sequenceDiagram
    actor HCP
    participant Page as hcpPortalHome
    participant Chat as Web chat (iframe)
    participant Agent as HCP Knowledge Agent
    participant Search as search_slides (ContentSearchAction)
    participant Show as show_slide (HcpShowSlideAction)

    HCP->>Page: log in, page loads
    Page->>Chat: loadScript(hcpChatInit) then embeddedservice_bootstrap.init
    HCP->>Chat: "Where should I administer the drug?"
    Chat->>Agent: message via messaging channel and routing flow
    Agent->>Search: query
    Search-->>Agent: matching slides (page ids, text)
    Agent-->>Chat: answer from slide text + "Would you like to see the slide?"
    HCP->>Chat: "yes"
    Chat->>Agent: message
    Agent->>Show: pageId (once)
    Show-->>Agent: c__hcpSlideCLT (title, slide, thumbnailUrl)
    Agent-->>Chat: structured output
    Chat->>Chat: enhancedWebChat renders hcpSlideCard inline
```

## 3. Routing from the chat to the agent

```mermaid
flowchart LR
    S[New MIAW session] --> MC[MessagingChannel<br/>sessionHandlerFlow]
    MC --> F[Flow HCP_Portal_Route_to_Agent]
    F --> R{routeWork}
    R -->|copilotId = BotDefinition<br/>HCP_Knowledge_Agent| Ag[Agent handles session]
    R -.->|fallback queue| Q[SDO Service Messaging queue]
```

## 4. Who runs what (permissions)

The key design constraint: Apex actions run as the **agent user**, not as the portal user.

```mermaid
flowchart TB
    subgraph PortalUser["Portal user (HCP User profile)"]
        P1[permission set HCP_Portal_Access]
        P2[Network membership: HCP User profile]
    end
    subgraph AgentUser["Agent user (shared service agent user)"]
        G1[HCP_Knowledge_Agent_Access]
        G2[GenieUserEnhancedSecurity]
        G3[LifeSciencesFieldSalesRepresentative]
        G4[PSL IndustriesLSC4CEPsl]
    end
    P1 --> Ctl[HcpPortalController.getSlides]
    Ctl --> CS[(HCP_Slide_Thumbnail__c)]
    G1 --> A[ContentSearchAction, HcpShowSlideAction]
    G2 --> Srch[Data 360 search]
    G3 & G4 --> PP[(PresentationPage)]
    A --> CS
    Admin([Admin script]) -->|creates links, fills| CS
    Admin --> CD[(ContentDistribution)]
```

Why the thumbnail setting exists: the agent user cannot insert `ContentDistribution`, sees its rows with blank fields and cannot read
`ContentVersion`. Portal users cannot read `PresentationPage` or `ContentDistribution` either. So an admin script creates the public links
once and copies title + URL into the `HCP_Slide_Thumbnail__c` list custom setting, which both the agent action and the portal controller read.

## 5. Thumbnail data flow

```mermaid
flowchart LR
    Script[publishImmunexisThumbnails.apex<br/>run as admin] --> Find[PresentationLinkedPage<br/>of Immunexis]
    Find --> Files[ContentDocumentLink images]
    Files --> Dist[create ContentDistribution<br/>public links]
    Dist --> Set[(HCP_Slide_Thumbnail__c<br/>Name = PresentationPage Id,<br/>Title__c, Thumbnail_Url__c)]
    Set --> Tiles[Portal tiles via getSlides]
    Set --> CardOut[hcpSlideCard thumbnail via show_slide]
```

## 6. Why the chat loads through a static resource

The LWR site sends a Content Security Policy with `script-src 'self'` plus hashes, so the standard inline snippet
(`function initEmbeddedMessaging(){...}`) in head markup is blocked and the chat never starts. `hcpChatInit.js` is served from the site's own
origin, so it is allowed. It creates the `bootstrap.min.js` script tag from the deployment's site URL and calls
`embeddedservice_bootstrap.init(orgId, 'HCP_Portal_Agent', siteUrl, { scrt2URL })`. `hcpPortalHome` loads it with `loadScript` in `renderedCallback`.

## 7. Deployment topology

```mermaid
flowchart LR
    Repo[Repo force-app] -->|sf project deploy| Org[(YOUR_ORG_ALIAS)]
    Scratch["Scratch project /tmp/hcp_esd<br/>(site bundle, Network)"] -->|sf project deploy| Org
    Org -->|POST connect/communities/id/publish| Live[Live site]
    Org -->|POST connect/embeddedmessaging/deployment/setup<br/>one time| ESC[EmbeddedServiceConfig]
    Org -->|sf agent validate, publish, activate| Agent[Agent]
```

The site bundle (`DigitalExperienceBundle`) and the `Network` live in a scratch project outside this repo; retrieve them again with
`sf project retrieve start -m "DigitalExperienceBundle:site/HCP_Portal1" -m "DigitalExperienceConfig:HCP_Portal1" -m "Network:HCP Portal"` if needed.
