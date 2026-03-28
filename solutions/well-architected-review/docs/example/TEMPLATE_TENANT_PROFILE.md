# Tenant Profile

> Describes the AWS tenant environment this workload deploys into. The Well-Architected Review's governance profiler reads this document to determine which controls are inherited from the organization and which remain the workload's responsibility.
>
> **Instructions:** Replace placeholder text in brackets with your environment's details. For sections that do not apply, keep the heading and write "Not applicable — [brief reason]." Do not delete sections — the governance profiler needs to distinguish "not applicable" from "not provided." Remove this instructions block when complete.
>
> **Partial completion is acceptable.** The governance profiler will ask up to 3 rounds of clarifying questions for gaps. Fill in what you know and leave brackets for unknowns.
>
> **Single-account environment?** If this workload runs in a standalone AWS account (not part of an AWS Organization), see [Appendix A: Single-Account Environments](#appendix-a-single-account-environments) for a streamlined path.

- **Last Updated:** [YYYY-MM-DD]

## Governance Framework

<!-- What governance structure manages your AWS accounts? Data owner: Cloud/Platform team lead. CLI: aws organizations describe-organization -->

- **Framework:** [e.g., AWS Control Tower with Landing Zone Accelerator / Custom landing zone / None — accounts managed individually]
- **Management account:** [Account ID or alias, or "N/A — no Organization"]
- **Governance tooling:** [e.g., Service Catalog for account vending, AFT for account factory, custom scripts]
- **Third-party governance tools:** [e.g., Prisma Cloud, Wiz, HashiCorp Sentinel, or "None"]

## Account Structure

<!-- How are your AWS accounts organized? Include the OU hierarchy and where this workload's account sits. Data owner: Cloud/Platform team. CLI: aws organizations list-accounts, aws organizations list-organizational-units-for-parent -->

- **Organization:** [Yes/No — is the account part of an AWS Organization?]
- **OU placement:** [e.g., Workloads/Production, Sandbox, or root]
- **Account vending:** [How are new accounts provisioned? e.g., Control Tower Account Factory, AFT, manual]
- **Environment strategy:** [e.g., separate accounts per environment (dev/staging/prod), single account with resource tagging, etc.]

### Account Topology

<!-- Optional: describe the account layout relevant to this workload. -->

| Account | Purpose | OU |
|---------|---------|-----|
| [e.g., Workload-Prod] | [Production workload] | [e.g., Workloads/Prod] |
| [e.g., Workload-Dev] | [Development and testing] | [e.g., Workloads/Dev] |
| [e.g., Shared-Services] | [Shared tooling, CI/CD] | [e.g., Infrastructure] |
| None | Single-account workload | N/A |

## Inheritable Controls

<!-- What preventive and detective controls are enforced at the organization or OU level? These controls apply to the workload account automatically. The reviewer uses this to determine which security controls are enforced at the organization level and do not need workload-level implementation. Scope values: Organization-wide | [OU name] OU | [Account name] account -->

### Service Control Policies (SCPs)

<!-- List all SCPs applied at the Organization or OU level that affect the workload account. When in doubt, include it — the reviewer will determine relevance. Data owner: Security/Platform team. CLI: aws organizations list-policies --filter SERVICE_CONTROL_POLICY -->

| SCP | Effect | Scope | Type | Covers Workload? | Workload Responsibility |
|-----|--------|-------|------|-------------------|-------------------------|
| [e.g., Deny root account usage] | [Blocks root user API calls] | [Organization-wide] | [Preventive] | [Yes] | [None] |
| [e.g., Restrict regions] | [Limits API calls to approved regions only] | [Organization-wide] | [Preventive] | [Yes] | [None] |
| [e.g., Deny S3 public access] | [Blocks public bucket policies and ACLs] | [Workloads OU] | [Preventive] | [Yes] | [None] |
| None | No organization-level SCPs beyond AWS defaults | N/A | N/A | Unknown | Workload manages own permissions boundaries |

### Guardrails

<!-- If using Control Tower or LZA, list enabled guardrails by name and category. Data owner: Control Tower admin. Console: AWS Control Tower > Guardrails. -->

| Guardrail | Category | Status | Covers Workload? | Workload Responsibility |
|-----------|----------|--------|-------------------|-------------------------|
| [e.g., Disallow public S3 buckets] | [Mandatory] | [Enabled] | [Yes] | [None] |
| [e.g., Detect MFA not enabled for root] | [Strongly recommended] | [Enabled] | [Partial] | [Workload must enable MFA for IAM users] |
| [e.g., Detect unrestricted SSH access] | [Elective] | [Enabled] | [Yes] | [None] |
| None | No Control Tower guardrails in use | N/A | N/A | Unknown | N/A |

### AWS Config Rules

<!-- List organization-wide Config rules that apply to the workload account. Include all rules that are relevant to the workload — the reviewer will determine pillar mapping. Data owner: Security/Platform team. CLI: aws configservice describe-organization-config-rules -->

| Rule | What It Checks | Scope | Type | Covers Workload? | Workload Responsibility |
|------|---------------|-------|------|-------------------|-------------------------|
| [e.g., s3-bucket-server-side-encryption-enabled] | [S3 buckets have encryption] | [Organization-wide] | [Detective] | [Yes] | [None — encryption enforced by org] |
| [e.g., ec2-instance-no-public-ip] | [EC2 instances have no public IPs] | [Workloads OU] | [Detective] | [Yes] | [None] |
| None | No organization-wide Config rules | N/A | N/A | Unknown | Workload must configure own Config rules |

### Security Hub Standards

<!-- Which Security Hub standards are enabled at the organization level? Data owner: Security team. CLI: aws securityhub get-enabled-standards -->

| Standard | Status | Scope | Covers Workload? | Workload Responsibility |
|----------|--------|-------|-------------------|-------------------------|
| [e.g., AWS Foundational Security Best Practices] | [Enabled] | [Organization-wide] | [Yes] | [Workload must remediate own findings] |
| [e.g., CIS AWS Foundations Benchmark v1.4.0] | [Enabled] | [Organization-wide] | [Yes] | [Workload must remediate own findings] |
| [e.g., NIST SP 800-53 Rev. 5] | [Enabled] | [Organization-wide] | [Partial] | [Workload must implement app-level controls] |
| None | No Security Hub standards enabled at org level | N/A | N/A | Unknown | Workload must enable and configure Security Hub |

## Centralized Services

<!-- What services are provided centrally by the organization? The workload benefits from these without needing to configure them. For each service, note whether the workload account has local access to findings/data or only the central account does. Data owner: Platform/Security team. -->

### Logging and Monitoring

| Service | Scope | Details | Covers Workload? | Workload Responsibility |
|---------|-------|---------|-------------------|-------------------------|
| [e.g., AWS CloudTrail] | [Organization trail, all regions] | [Logs delivered to central logging account] | [Yes] | [Workload must configure application-level logging] |
| [e.g., AWS Config] | [Organization-wide recorder] | [Configuration history in central account] | [Yes] | [None — recorder covers all resources] |
| [e.g., VPC Flow Logs] | [Centrally enabled for all VPCs] | [Delivered to central S3 bucket / CloudWatch] | [Yes] | [None] |
| [e.g., Centralized logging] | [Central logging account] | [Log archive with retention policy of N years] | [Yes] | [Workload must ship app logs to central pipeline] |
| [e.g., Centralized alerting] | [Organization-wide EventBridge / SNS] | [Critical alerts routed to central SOC] | [Partial] | [Workload must define application-specific alarms] |
| None | No centralized logging or monitoring | N/A | N/A | Unknown | Workload must implement all logging and monitoring |

### Security Services

| Service | Scope | Details | Covers Workload? | Workload Responsibility |
|---------|-------|---------|-------------------|-------------------------|
| [e.g., Amazon GuardDuty] | [Organization-wide, delegated admin] | [Findings aggregated in security account] | [Yes] | [Workload must remediate own findings] |
| [e.g., AWS Security Hub] | [Organization-wide, delegated admin] | [Findings aggregated in security account] | [Yes] | [Workload must remediate own findings] |
| [e.g., Amazon Inspector] | [Organization-wide] | [Automated vulnerability scanning] | [Yes] | [Workload must remediate vulnerabilities found] |
| [e.g., Amazon Macie] | [Enabled/Not enabled] | [S3 data classification] | [Partial] | [Workload must classify sensitive data in new buckets] |
| [e.g., AWS IAM Access Analyzer] | [Organization-wide] | [External access findings] | [Yes] | [Workload must remediate own findings] |
| [e.g., Incident response plan] | [Organization-wide] | [Central IR playbook and on-call rotation] | [Partial] | [Workload must define app-specific runbooks and escalation paths] |
| None | No centralized security services | N/A | N/A | Unknown | Workload must implement all security monitoring |

### Identity

| Service | Scope | Details | Covers Workload? | Workload Responsibility |
|---------|-------|---------|-------------------|-------------------------|
| [e.g., IAM Identity Center (SSO)] | [Organization-wide] | [Centrally managed permission sets and groups] | [Yes] | [Workload must request appropriate permission sets] |
| [e.g., External IdP integration] | [e.g., Azure AD, Okta] | [Federated access for human users] | [Yes] | [None — human access managed centrally] |
| [e.g., Permission model] | [Organization-wide] | [Centrally defined permission sets only / workload teams can create custom sets] | [Partial] | [Workload must define least-privilege IAM roles for services] |
| None | No centralized identity management | N/A | N/A | Unknown | Workload must manage all IAM |

## Network Boundaries

<!-- How is the network managed at the organization or shared-infrastructure level? Data owner: Network team. CLI: aws ec2 describe-transit-gateways, aws ec2 describe-vpcs -->

### Connectivity

| Component | Details | Covers Workload? |
|-----------|---------|-------------------|
| [e.g., Transit Gateway] | [Hub-and-spoke, shared across workload accounts via RAM] | [Yes] |
| [e.g., VPC patterns] | [Standardized VPC CIDR ranges, subnet layout provided by network team] | [Yes] |
| [e.g., Shared VPCs] | [Yes — workload deploys into shared subnets owned by network team. Subnets: private app tier, private data tier. VPC owner account: 123456789012] | [Yes] |
| [e.g., VPN / Direct Connect] | [Hybrid connectivity to on-premises via Transit Gateway] | [Partial] |
| [e.g., VPC Endpoints / PrivateLink] | [Centralized interface endpoints for S3, DynamoDB, ECR in shared-services VPC] | [Partial] |
| None | No centralized network infrastructure | Unknown |

### DNS

| Component | Details | Covers Workload? |
|-----------|---------|-------------------|
| [e.g., Route 53 private hosted zones] | [Centrally managed, shared with workload accounts] | [Yes] |
| [e.g., DNS resolution] | [Inbound/outbound resolver endpoints in shared-services account] | [Yes] |
| None | No centralized DNS management | Unknown |

### Ingress Controls

<!-- What controls govern inbound traffic to the workload? Data owner: Network/Security team. -->

| Component | Details | Covers Workload? |
|-----------|---------|-------------------|
| [e.g., AWS WAF] | [Centralized WAF rules on shared ALB or CloudFront distribution] | [Yes] |
| [e.g., AWS Shield Advanced] | [Organization subscription, applied to public-facing resources] | [Partial] |
| [e.g., Network ACLs] | [Standardized NACLs applied to shared VPC subnets] | [Yes] |
| None | No centralized ingress controls | Unknown |

### Egress Controls

| Component | Details | Covers Workload? |
|-----------|---------|-------------------|
| [e.g., Centralized NAT Gateway] | [Shared egress through network account] | [Yes] |
| [e.g., AWS Network Firewall] | [Centralized inspection of egress traffic] | [Yes] |
| [e.g., Web proxy] | [HTTP/HTTPS traffic routed through centralized proxy] | [Partial] |
| None | No centralized egress controls | Unknown |

## Compliance Baselines

<!-- What compliance frameworks are satisfied (in whole or in part) at the organization level? The workload inherits these controls and does not need to re-implement them. Do not reference external documents — summarize inherited controls inline. Data owner: GRC/Compliance team. -->

| Framework | Scope | Inherited Controls | Covers Workload? | Workload Responsibility |
|-----------|-------|--------------------|-------------------|-------------------------|
| [e.g., SOC 2 Type II] | [Organization-wide] | [Access management, change management, monitoring, incident response] | [Yes] | [Workload must implement app-level access controls] |
| [e.g., ISO 27001] | [Organization-wide] | [ISMS controls: risk management, asset management, physical security] | [Yes] | [Workload must implement technical controls for data handling] |
| [e.g., HIPAA BAA] | [Specific accounts] | [BAA in place, eligible services configured, encryption enforced] | [Partial] | [Workload must use eligible services and encrypt PHI at app level] |
| None | No organization-level compliance frameworks | N/A | N/A | Workload must independently satisfy all compliance requirements |

### Workload-Specific Compliance Requirements

<!-- Compliance requirements that go beyond the organization baseline. Examples: PCI DSS for a payment workload, HIPAA for health data, data residency for regulated workloads. Data owner: Compliance/GRC team. -->

| Requirement | Scope | Org Coverage | Status | Workload Responsibility |
|-------------|-------|-------------|--------|-------------------------|
| [e.g., PCI DSS v4.0] | [Workload-specific] | [None — org does not hold PCI certification] | [In progress] | [Workload team — full responsibility] |
| [e.g., Data residency — Canada only] | [Workload-specific] | [Partial — SCP restricts regions] | [Enforced] | [Shared — SCP restricts regions, workload selects ca-central-1] |
| None | N/A | N/A | N/A | No workload-specific compliance requirements beyond org baselines |

## Shared Resources

<!-- What resources are managed centrally and shared with (or available to) the workload account? Data owner: Platform team. CLI: aws ram list-resources -->

| Resource | Details | How Accessed | Required? |
|----------|---------|-------------|-----------|
| [e.g., Shared KMS keys] | [Organization-wide encryption keys for specific services] | [Key policy grants cross-account access] | [Mandatory] |
| [e.g., Central certificate authority] | [ACM Private CA in security account] | [RAM share to workload accounts] | [Recommended] |
| [e.g., Container image registry] | [ECR in shared-services account] | [Cross-account pull permissions] | [Mandatory] |
| [e.g., Artifact repositories] | [CodeArtifact / S3-based package repos] | [Cross-account access via resource policy] | [Optional] |
| [e.g., CI/CD pipelines] | [Central pipeline account deploys to workload accounts] | [Cross-account IAM roles] | [Mandatory] |
| None | No centrally shared resources | N/A | N/A |

## Backup, Recovery, and Resilience

<!-- Organization-level backup and disaster recovery capabilities. The reviewer uses this to assess Reliability pillar inherited controls. Data owner: Operations/Platform team. CLI: aws backup list-backup-plans -->

### Backup Policies

| Setting | Details |
|---------|---------|
| Centralized backup | [e.g., AWS Backup with organization-wide policies / per-account / none] |
| Backup vault | [e.g., Central vault in management account with cross-account backup] |
| Retention policy | [e.g., 30 days standard, 7 years for compliance] |
| Testing frequency | [e.g., Quarterly restore tests / annual / none] |
| Cross-region replication | [e.g., Backups replicated to ca-west-1 / not configured] |

### Disaster Recovery and Resilience

<!-- Recommended — complete if applicable. -->

| Setting | Details |
|---------|---------|
| RTO target | [e.g., 4 hours / 24 hours / not defined at org level] |
| RPO target | [e.g., 1 hour / 24 hours / not defined at org level] |
| Multi-AZ strategy | [e.g., All production workloads must span 2+ AZs / not enforced] |
| Multi-Region strategy | [e.g., Active-passive in ca-central-1 and ca-west-1 / single region only] |
| Failover automation | [e.g., Route 53 health checks with automated failover / manual] |
| Resilience Hub | [e.g., Enrolled / not enrolled / not applicable] |

## Cost Governance

<!-- Recommended — complete if applicable. Organization-level cost management controls. The reviewer uses this to assess Cost Optimization pillar inherited controls. Data owner: FinOps/Finance team. CLI: aws ce get-cost-and-usage -->

| Setting | Details |
|---------|---------|
| Consolidated billing | [e.g., Single payer account with all workload accounts / separate billing / N/A] |
| RI / Savings Plans | [e.g., Organization-wide Compute Savings Plans managed by FinOps / none] |
| Budgets | [e.g., AWS Budgets set per account with alert thresholds / not configured] |
| Cost Anomaly Detection | [e.g., Enabled organization-wide with SNS alerts / not configured] |
| Chargeback / showback | [e.g., CUR with Athena, cost allocation by CostCenter tag / none] |
| Cost allocation tags | [e.g., Activated: CostCenter, Project, Environment / none activated] |
| Not applicable | No organization-level cost governance — workload manages independently |

## Change Management

<!-- Recommended — complete if applicable. Organization-level change control processes. The reviewer uses this to assess Operational Excellence pillar inherited controls. Data owner: DevOps/Platform team. -->

| Setting | Details |
|---------|---------|
| Deployment tooling | [e.g., Centralized CodePipeline / GitHub Actions with org runners / per-team choice] |
| Deployment guardrails | [e.g., Mandatory canary deployments / blue-green enforced by pipeline / none] |
| Approval gates | [e.g., Production deployments require CAB approval / peer review only / none] |
| Change windows | [e.g., Production changes only during business hours / no restrictions] |
| Runbooks | [e.g., Centralized runbook library in Systems Manager / per-team wikis / none] |
| Not applicable | No centralized change management — workload team manages independently |

## Operational Context

<!-- Remaining operational details relevant to the Well-Architected Review that are not covered above. -->

### Tagging Strategy

- **Required tags:** [e.g., Environment, Project, CostCenter, Owner]
- **Enforcement:** [e.g., SCP denies resource creation without required tags / tag policies / advisory only]

### Patching

- **Managed patching:** [e.g., Systems Manager Patch Manager with org-wide baselines / per-account / none]
- **Patch windows:** [e.g., Weekly maintenance windows defined centrally]

---

## Appendix A: Single-Account Environments

<!-- If the workload runs in a standalone AWS account (not part of an AWS Organization), use this guide to complete the template efficiently. -->

If you are not part of an AWS Organization, many sections above will not apply. Fill in the template as follows:

| Section | Action |
|---------|--------|
| Governance Framework | Write "Not applicable — standalone account, no centralized governance." |
| Account Structure | Fill in Organization: No. Write "Not applicable" for OU placement and account vending. |
| Inheritable Controls | Write "Not applicable — no organization-level controls" for all subsections. |
| Centralized Services | Document any services you have enabled directly in the account (e.g., GuardDuty, Config). |
| Network Boundaries | Fill in — these apply to your account's VPC configuration regardless of Organization membership. |
| Compliance Baselines | Fill in — compliance requirements apply at the workload level. |
| Shared Resources | Write "Not applicable" unless you use cross-account resources. |
| Backup, Recovery, and Resilience | Fill in — critical regardless of account structure. |
| Cost Governance | Fill in — relevant even for single accounts. |
| Change Management | Fill in — relevant even for single accounts. |
| Operational Context | Fill in — tagging and patching apply to all accounts. |

## Appendix B: Data Collection Guide

<!-- Reference for who to ask and how to retrieve information for each section. You may not have access to all of this data — ask the listed team or share this table with them. -->

| Section | Data Owner | How to Gather |
|---------|-----------|---------------|
| Governance Framework | Cloud/Platform team lead | `aws organizations describe-organization` |
| Account Structure | Cloud/Platform team | `aws organizations list-accounts` and `aws organizations list-organizational-units-for-parent` |
| SCPs | Security/Platform team | `aws organizations list-policies --filter SERVICE_CONTROL_POLICY` then `aws organizations list-targets-for-policy` |
| Guardrails | Control Tower admin | AWS Control Tower console > Guardrails, or ask the landing zone team |
| Config Rules | Security/Platform team | `aws configservice describe-organization-config-rules` |
| Security Hub Standards | Security team | `aws securityhub get-enabled-standards` |
| Centralized Services | Platform/Security team | Review shared-services documentation or ask the platform team for a service catalog |
| Network Boundaries | Network team | `aws ec2 describe-transit-gateways`, `aws ec2 describe-vpcs`, `aws route53resolver list-resolver-endpoints` |
| Compliance Baselines | GRC/Compliance team | Request the organization's control inheritance matrix or compliance attestation scope |
| Shared Resources | Platform team | `aws ram list-resources` for RAM-shared resources |
| Backup and Resilience | Operations/Platform team | `aws backup list-backup-plans` and ask for DR runbooks |
| Cost Governance | FinOps/Finance team | `aws ce get-cost-and-usage`, check AWS Budgets console |
| Change Management | DevOps/Platform team | Review CI/CD pipeline configurations and change management policy |
