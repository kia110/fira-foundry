## Introduction

Usual DAO is launching a bug bounty program for the Fira UZR (Usual Zero Rate) module deployed on Ethereum mainnet. Fira is a new standalone lending/borrowing protocol (owned by the Usual DAO) specializing in fixed-rate credit. The UZR module is a custom vault within Fira that offers essentially low-cost borrowing: users can post bUSD0 (a yield-bearing USD0 collateral token) as collateral to borrow USD0 stablecoin at a fixed 0% interest rate (with only a 0.1% annual service fee). This module is the successor to Usual’s Euler-based “Usual Stability Loan (USL)” system, migrating that liquidity into Usual’s own infrastructure.

This bug bounty focuses on vulnerabilities in the Fira UZR smart contracts and associated components that could compromise funds or protocol integrity. Only the contracts currently deployed on Ethereum mainnet (listed below) are considered in-scope. The migration and UZR vault have been extensively audited by both Labs team and independent auditors, but we now invite the community to help identify any remaining security issues.

## Reward Amounts

- Critical: Up to $7,500,000 maximum payout (not to exceed 10% of the funds at risk at time of submission). Critical findings are those that would result in a definite and significant loss of funds or an irreversible locking of funds on a systemic level. The minimum payout for a valid critical issue is $200,000.
- High: Discretionary. High severity payouts will be determined on a case-by-case basis by Usual Labs (amount will reflect the impact and severity).
- Medium: Discretionary. Medium severity payouts will be determined on a case-by-case basis by Usual Labs.

**Note**: Actual reward amounts for valid reports will be decided upon triage and severity assessment by Sherlock’s security team, up to the caps listed above. Lower-severity issues (e.g. Low or Informational) are not eligible for rewards under this program.

## Severity Criteria

### Critical Severity – Definition:

- Leads to definite and significant loss of funds (theft or irrecoverable loss of collateral or stablecoins) without reliance on extreme or external conditions.
- Leads to definite and significant freezing of funds for >1 year without external conditions (e.g. permanent lock of user funds or system-wide halt).
- Only vulnerabilities in the core contracts (see scope below) qualify for Critical severity.
- Typically, issues that could directly result in theft or irreversible loss of ~5% or more of the protocol’s Total Value Locked (TVL) fall under Critical.

### High Severity – Definition:

- Could cause significant loss of funds or value, though generally affecting a smaller portion of TVL (approximately 1%–5% of TVL at risk) or requiring certain unlikely conditions to exploit.
- Could cause significant fund freezing or denial of service affecting many users (e.g. inability to withdraw or a temporary halt) without external factors.
- High-severity issues may also include vulnerabilities in secondary contracts that, while not core, can be exploited to cause substantial economic damage to the protocol or many users.

### Medium Severity – Definition:

- Vulnerabilities that could cause loss of funds or permanent lock of funds for individual users (user-level impact rather than systemic).
- Issues that degrade security or availability but with limited scope or impact (e.g. affecting only specific edge-case scenarios or requiring complex preconditions).

### General Notes:

- We encourage all reporters to consult Sherlock’s Criteria for Issue Validity guide for general guidance on severity and out-of-scope issues. However, note that the definitions above will be the ultimate criteria for this bounty program’s severities.
- A working Proof of Concept (POC) exploit is highly recommended (and may be required for complex issues) to demonstrate the validity and impact of the vulnerability. Please include detailed instructions so our engineers can reproduce the issue.
- If the protocol team has the ability to mitigate an exploit (e.g. by pausing contracts, upgrading implementations, or triggering an emergency shutdown), we assume that such measures will be taken within a 1-hour window of detecting an ongoing exploit. In assessing the worst-case impact of a vulnerability, consider the damage achievable within that 1-hour response window.
- Please review the official Sherlock Bug Bounty Platform Rules before submitting any vulnerability. All standard Sherlock platform rules and safe harbor policies apply to this program.

## Out of Scope

The following areas are out-of-scope for this bounty (no rewards will be awarded for issues solely in these categories):

- Unaudited or Undeployed Code: Any contracts or code that are not deployed on Ethereum mainnet (e.g. testnet contracts, development versions, or future features not yet live) are not in scope.
- Previously Known Issues: Any vulnerabilities or issues already identified in prior audits or documented by Usual Labs are not eligible. (If you are unsure whether an issue is known, you can ask the team or Sherlock triage for clarification when submitting.)
- Frontend / UI/Website Issues: Bugs or vulnerabilities in any front-end website or application (UI/UX issues) are not part of the core scope. (Such issues may be reported to Usual separately and could be eligible for a separate reward at the team’s discretion, but they do not qualify under this smart contract bounty.)
- Third-Party Integrations: Issues in integrations with external protocols or platforms are out-of-scope. For example, vulnerabilities in external liquidity pools, third-party yield strategies, or any platform that the UZR contracts interact with but that is not controlled by Usual (e.g. if USD0 is used in a Curve pool or a bridge) are not covered.
- External Oracles and RWA Contracts Not Maintained by Usual: Bugs in third-party oracle systems or real-world asset token contracts that Usual/Fira rely on (but do not control) are out-of-scope. For instance, any exploit requiring the Chainlink price feed to fail/malfunction or an RWA custodian’s off-chain process to be compromised would not be considered a valid vulnerability in UZR’s smart contracts.
- RWA Tokenization Risks & Off-Chain Events: Any risks or issues deriving purely from real-world asset backing or off-chain processes (e.g. a custodian default, legal failure, or off-chain oracle signer collusion) are out-of-scope. The bug bounty is concerned only with on-chain smart contract vulnerabilities, not the economic or off-chain legal risks of the stablecoin system.
- Admin/Privileged Actions (Intended Behavior): Issues that can only be triggered by accounts with proper administrative or governance permissions (and are intended as part of the design) are out-of-scope. For example, the Usual DAO has the ability to adjust certain parameters, pause contracts, or perform forced liquidations at the bUSD0 maturity – these are expected privileges. A scenario where the authorized DAO uses its permissions maliciously is not considered a bug. (However, if you find a way to exploit or mimic an admin-only function without having the privileges, that is very much in scope.)
- Protocol-Intended Behaviors: Behavior that is explicitly intended by the protocol design, even if it may be unfavorable to some users, is not a vulnerability. For example, forced liquidation at maturity of the bUSD0 collateral is by design. When the bUSD0 token reaches its maturity date (June 11, 2028, 11:30 UTC), the DAO and maintenance Labs can liquidate any remaining USD0 loans regardless of health factors. This ensures bUSD0 can be redeemed and burned. This is an intended mechanic and should not be reported as an issue.
- Minor Efficiency/Gas Issues: Pure gas optimizations or minor inefficiencies with no security impact are out-of-scope. Similarly, minor rounding errors or precision issues that do not materially affect contract security or user funds are not eligible.
- Theoretical/Brute-Force Attacks: Vulnerabilities that require truly impractical levels of brute force, extreme luck, or unrealistic attack scenarios (e.g. exploiting the random beacon by controlling enormous hash power, etc.) are out-of-scope. Issues should have a credible and reproducible attack path.
- Economic or Market Manipulation Attacks (Without Code Exploit): Pure economic attacks that do not involve a flaw in the smart contracts are out-of-scope. For instance, scenarios requiring extreme market manipulation, such as dramatically devaluing collateral through off-chain means or exploiting an intended pricing assumption (the UZR system intentionally treats bUSD0 as 1:1 with USD0) are not considered smart contract vulnerabilities unless there is an unexpected failure in contract logic. (In short, if a user can cause a loss only by doing something within the expected rules of the protocol, like normal trading or using the oracle as designed, that is not a bug.)
- Third-Party Platform Risks: Any vulnerabilities in underlying platforms not owned by Usual Labs. For example, issues in the Euler protocol (outside of the provided migrator contract) or in bridges (e.g. LayerZero, CCIP, etc.) that might be used to move USD0 are not in scope here. Similarly, if the security of Circle (USDC issuer) or another external entity is compromised, that falls outside this bounty’s scope.
- Documentation and Comment Issues: Missing or misaligned NatSpec comments, spelling mistakes in documentation, or any purely informational/documentation issues without a security impact are not in scope.

If you are unsure whether an issue is in scope, we encourage you to reach out for clarification before investing significant time. When in doubt, focus on finding on-chain, technical vulnerabilities in the contracts listed in the Scope section.

## Protocol Resources

For more information about the protocol design and to aid your review, you may consult the following resources:

- Fira Documentation: docs.fira.money – Official documentation for Fira, including overviews of the UZR module and FAQs.
- Contracts & Audits List: docs.fira.money/resources-and-ecosystem/contracts-and-audits – A list of deployed contract addresses (as given above) and references to any audit reports or security resources.
- Usual Protocol FAQ: docs.fira.money/overview/faq – Frequently Asked Questions, which may cover aspects of USD0, bUSD0, and the UZR system behavior.
- Usual Money Docs: You may also reference the broader Usual protocol documentation at docs.usual.money for context on USD0 stablecoin, USUAL token, and the overall system design (note that not all of it is directly relevant to the UZR vault).

These resources can provide valuable background, but remember that the ultimate scope of the bounty is defined by the on-chain contracts as described above.

## Judging and Severity Assessment

All submissions will be triaged and validated by Sherlock’s security team. Sherlock will coordinate the verification of the issue and determine the severity level based on the impact, in line with the criteria outlined above. Usual Labs will be consulted during this process but will not directly judge submissions or severity – the final determination of validity and severity (and thus the reward amount) lies with Sherlock, according to the program’s rules.

In case of any dispute or ambiguity in severity ratings, Sherlock’s assessment will be the deciding factor, guided by the definitions and scope established in this bounty.

## Disclosure Policy

This bounty program follows Sherlock’s standard disclosure policy with additional requirements specific to critical vulnerabilities:

- Critical findings (e.g. vulnerabilities that could lead to severe loss of funds) must not be disclosed publicly or to any third party until all of the following are met: (1) Usual Labs has been notified and acknowledged the issue, (2) a fix or mitigation has been deployed on mainnet, and (3) explicit permission to disclose details has been granted by Usual Labs. Premature public disclosure of a critical issue (or any attempt to exploit it in the wild) will disqualify the submission from any reward.
- We ask that any discovered vulnerability be reported within 24 hours of discovery through the official submission process (via Sherlock). Prompt reporting helps us address issues faster and reduce potential harm.
- Do not exploit any vulnerabilities on the live network. You are expected to abide by good faith conduct: no stealing funds, no modifying or destroying data, and no disrupting the service. Exploiting the bug beyond what is necessary to demonstrate it (for example, taking profit or engaging in blockchain blackmail) will result in disqualification and potential legal consequences.
- Public disclosure or sharing of exploit details before a fix is in place is strictly prohibited. If you believe others have discovered the issue or it’s being actively exploited, please inform us and Sherlock immediately, but still do not make it public.

Usual Labs may, at its discretion, offer additional compensation or bonuses for particularly novel or high-impact discoveries that are handled according to these disclosure rules (on top of the standard bounty payout). Our goal is to encourage responsible disclosure and we’re willing to reward those who help keep the protocol safe.

## Eligibility

To be eligible for a reward under this program, you must meet all the criteria below:

- No sanctions: You are not located in a country or region subject to international sanctions (e.g. you are not on the U.S. OFAC Specially Designated Nationals list or similar restrictions).
- No affiliation with Usual Labs: You are not a current or former employee or core contributor to the Usual project (including the Fira development team), and you are not directly affiliated with Usual Labs. Similarly, you are not an immediate family member of the project team. We want independent security researchers to participate without any conflicts of interest.
- Legal capacity: You are legally permitted to participate in bug bounty programs and receive rewards in your jurisdiction. (Minors under 18 may participate only with verifiable consent of a parent or guardian.)
- No prior auditors of this code: You have not performed a paid audit or security review of the Fira UZR contracts (or related Usual protocol code) in an official capacity. In other words, if you were already compensated to audit this system or contributed code to it, you should not submit findings here. (If you fall into this category but still believe you’ve found a critical issue, you can contact Usual Labs privately; any reward would be at the team’s discretion.)
- Follow program rules: You agree to abide by all the terms of this bounty program and the Sherlock platform rules. This includes respecting the scope, not engaging in forbidden testing (see below), and adhering to the disclosure policy outlined above.

By submitting a vulnerability report, you affirm that you meet these eligibility requirements. Usual Labs and Sherlock reserve the right to verify eligibility and to disqualify any participant found to be in violation of these terms.

## Testing Guidelines and Safe Harbor

We want to ensure that security researchers can test and investigate the contracts safely, without risking user funds or violating any laws:

- Do NOT test on mainnet with destructive actions: Please do not target the live contracts on Ethereum mainnet in any way that could disrupt services or affect real funds. Use a local test environment or a mainnet fork to test exploits. All the in-scope contracts are verified, so you can readily instantiate them in a test framework (e.g., Hardhat or Foundry fork) to experiment.
- Use your own accounts: When testing on a fork or test environment, use accounts you control. Do not interact with other users’ addresses or data except in read-only ways necessary to analyze a vulnerability.
- No denial-of-service on mainnet: Even if a potential issue relates to performance or blocking behavior, do not attempt to actually DoS the live system. Describe the issue in your report and demonstrate it in a controlled test if needed.
- Maintain confidentiality: As stated, do not share exploit details with anyone outside of the official submission process. This ensures others cannot maliciously use the information before a fix.
- No social engineering or physical attacks: This program is about smart contract/code security. Any attempt to phish, scam, or manipulate team members or users, or to gain unauthorized access to systems through non-technical means (e.g. social engineering, threats) is strictly forbidden and will result in disqualification.
- Follow responsible testing practices: Avoid unnecessarily high volumes of transactions or any behavior on mainnet that could be construed as attacking the network or spam. If you’re unsure whether a specific test is safe or allowed, please err on the side of caution and consult with us or Sherlock first.

We appreciate your help in keeping the protocol safe. As long as you act in good faith and within these guidelines, any accidental disruption or exposure that occurs as part of your security research will be forgiven and considered within the safe harbor of this program. We will not pursue legal action against researchers who abide by the rules and report vulnerabilities responsibly.

---

Thank you for participating in the Fira UZR bug bounty! Usual Labs greatly values the contributions of the white-hat community. Together, we can ensure that the new Fira UZR lending module is robust and secure, helping to maintain user trust and the protocol’s stability as it grows. Happy hunting!
