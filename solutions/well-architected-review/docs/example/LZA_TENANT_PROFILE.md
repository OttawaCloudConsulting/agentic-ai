# Tenant Profile — Landing Zone Accelerator (LZA) for CCCS Medium

> Preconfigured tenant profile for environments deployed with the [Landing Zone Accelerator on AWS](https://aws.amazon.com/solutions/implementations/landing-zone-accelerator-on-aws/) using the [CCCS Medium sample configuration](https://github.com/awslabs/landing-zone-accelerator-on-aws/tree/main/reference/sample-configurations/lza-sample-config-cccs-medium). This profile reflects the default LZA CCCS Medium reference architecture. Adjust values marked with `[VERIFY]` to match your deployment.
>
> **Compliance scope:** CCCS Medium Cloud Security Profile (formerly PBMM). As of September 12, 2025, 162 AWS services in the Canadian regions (ca-central-1 and ca-west-1) are assessed and meet CCCS Medium requirements. LZA with these sample configs addresses up to 70% of infrastructure-layer technical controls per ITSG-33 — remaining controls require workload-level implementation, operational procedures, and SA&A documentation.
>
> **Standards lineage:** CCCS Medium maps to ITSG-33 Annex 3A, which is derived from NIST 800-53 Rev. 5 with Canadian-specific modifications. References to NIST 800-53 in this profile reflect the underlying control framework via ITSG-33.
>
> **Instructions:** Review each section. Replace `[VERIFY]` placeholders with your environment-specific values. Sections without `[VERIFY]` reflect LZA defaults and can be accepted as-is unless your deployment deviates from the sample configuration.
>
> **LZA config version:** [VERIFY — insert your LZA version and CCCS Medium config commit/tag]

- **Last Updated:** [YYYY-MM-DD]

## Governance Framework

<!-- LZA deploys AWS Organizations with Control Tower (optional) and SCPs for CCCS Medium compliance. -->

- **Framework:** Landing Zone Accelerator on AWS (LZA) for CCCS Medium — deploys an opinionated multi-account architecture aligned with ITSG-33 and CCCS Medium Cloud Security Profile
- **Management account:** [VERIFY — Management account ID or alias]
- **Governance tooling:** LZA CodePipeline (CDK-based), AWS Organizations, AWS Control Tower (optional — disabled by default in sample config, enable if using Control Tower), Service Catalog (optional)
- **Third-party governance tools:** [VERIFY — e.g., Prisma Cloud, Wiz, or "None"]

## Account Structure

<!-- LZA provisions a multi-account structure with dedicated OUs for Security, Infrastructure, and workload tiers. -->

- **Organization:** Yes — AWS Organizations with SCPs, RCPs, and centralized governance
- **OU placement:** Workload accounts are placed in tier-specific OUs (Central, Dev, Test, Prod, UnClass, Sandbox)
- **Account vending:** LZA pipeline provisions mandatory and workload accounts via accounts-config.yaml. Control Tower Account Factory available if Control Tower is enabled.
- **Environment strategy:** Separate accounts per environment tier, each in its own OU with tier-specific SCPs

### Account Topology

| Account | Purpose | OU |
|---------|---------|-----|
| Management | Central governance, billing, organization management, root account | Root |
| LogArchive | Centralized log ingestion and archiving for all accounts | Security |
| Audit | Security tooling — GuardDuty, Security Hub, Config aggregation, Inspector, Macie delegated admin | Security |
| Network | Shared networking — Transit Gateway, Route 53 resolver, IPAM, centralized DNS | Infrastructure |
| Operations | Centralized IT operations — Managed Active Directory, IAM Identity Center delegated admin, rsyslog | Infrastructure |
| Perimeter | Internet-facing IaaS ingress/egress — AWS Network Firewall, NAT Gateways, ALB/NLB | Infrastructure |
| [Workload accounts] | Application workloads per tier | [VERIFY — Central / Dev / Test / Prod / UnClass / Sandbox] |

## Inheritable Controls

<!-- LZA deploys extensive SCPs, RCPs, DCPs, Config rules, and Security Hub standards organization-wide. These controls apply automatically to all workload accounts. -->

> **Column definitions:**
>
> - **Covers Workload?** — Does this control automatically protect workload accounts without any workload-team action? "Yes" = fully inherited. "Partial" = inherited but requires workload-specific configuration. "N/A" = not applicable to workloads.
> - **Workload Responsibility** — What the workload team must do (if anything) beyond inheriting the control.

### Service Control Policies (SCPs)

<!-- LZA deploys multiple SCP layers. Part 0 and Part 1 SCPs protect LZA-managed resources from modification. Sensitive and environment-specific SCPs enforce additional restrictions. -->

| SCP | Effect | Scope | Type | Covers Workload? | Workload Responsibility |
|-----|--------|-------|------|-------------------|-------------------------|
| Guardrails-Part-0 (Workload OUs) | Protects LZA-managed resources: Config rules, Lambda functions, SNS topics, EBS encryption, CloudWatch Logs/Streams, IAM roles/settings, GuardDuty, Security Hub, Macie, CloudFormation stacks, SSM parameters, S3 buckets, EventBridge, KMS, Kinesis, Network Firewall settings from modification | Central, Dev, Test, Prod, UnClass, Sandbox OUs | Preventive | Yes | None — LZA infrastructure is immutable |
| Guardrails-Part-0-Core | Same protections as Part 0, applied to core accounts | Security, Infrastructure OUs | Preventive | Yes | None |
| Guardrails-Part-1 | Protects CloudTrail (if not using Control Tower), restricts default VPC creation, blocks IGW/VPC/NAT Gateway/Transit Gateway/RAM modification, restricts account disassociation, protects Accelerator-tagged IAM roles, restricts Identity Center delegated admin changes | All OUs (Organization-wide) | Preventive | Yes | None |
| Guardrails-Sensitive | Restricts regions to approved Canadian regions only, enforces EFS encryption, enforces RDS encryption, blocks root account usage | Security, Infrastructure, Central, Dev, Test, Prod OUs | Preventive | Yes | None — encryption enforced at creation time |
| Guardrails-Unclass | Environment-specific restrictions for Unclassified tier | UnClass OU | Preventive | Yes | None |
| Guardrails-Sandbox | Environment-specific restrictions for Sandbox tier | Sandbox OU | Preventive | Yes | None |
| Quarantine-New-Object | Denies all API actions — applied to new accounts pending vetting | Applied per-account (quarantine) | Preventive | N/A | Accounts remain quarantined until explicitly released |

### Resource Control Policies (RCPs)

> **Note:** RCPs are NOT deployed by the CCCS Medium sample configuration by default. These policies are documented in the LZA Universal Configuration and may be available in newer LZA releases. [VERIFY — confirm your LZA version and organization-config.yaml.]

All RCPs below are Organization-wide, Preventive, fully cover workloads (no workload action required):

- **Organization-only access** (S3, SQS, KMS, Secrets Manager, STS) — restricts service operations to Organization members and AWS services only; denies requests originating from outside the Organization
- **HTTPS-only** (S3, SQS, KMS, Secrets Manager, STS) — denies actions over unencrypted HTTP
- **Control Tower S3 log protection** — restricts access to Control Tower audit log S3 objects to authorized services/roles only (if Control Tower enabled)
- **LZA KMS key protection** — restricts modification of LZA-managed KMS keys

### Declarative Control Policies (DCPs)

> **Note:** DCPs are NOT deployed by the CCCS Medium sample configuration by default. These policies are documented in the LZA Universal Configuration and may be available in newer LZA releases. [VERIFY — confirm your LZA version and organization-config.yaml.]

| DCP | Effect | Scope | Type | Covers Workload? | Workload Responsibility |
|-----|--------|-------|------|-------------------|-------------------------|
| VPC Block Public Access | Prevents unauthorized internet accessibility for VPC resources (deny-by-default) | Organization-wide (excludes Perimeter account and Sandbox OU) | Preventive | Yes | None — public internet access must go through the Perimeter account |

### Guardrails

> **Note:** Control Tower is disabled in the default CCCS Medium sample config. Guardrails below are only active if Control Tower is explicitly enabled.

| Guardrail | Category | Status | Covers Workload? | Workload Responsibility |
|-----------|----------|--------|-------------------|-------------------------|
| Control Tower mandatory guardrails | Mandatory | Enabled (if Control Tower enabled) | Yes | None |
| Control Tower strongly recommended guardrails | Strongly recommended | Enabled (if Control Tower enabled) | Yes | None |
| Control Tower Dashboard compliance monitoring | Detective | Enabled (if Control Tower enabled) | Yes | Workload must remediate flagged findings |

### AWS Config Rules

LZA CCCS Medium deploys 27 Config rules (25 managed + 2 custom) with automated remediation for 5 key rules. An additional 12 rules available in the broader LZA Universal Configuration are listed in [Appendix D](#appendix-d-recommended-additional-config-rules).

> **Regional scope:** Config rules exclude ap-northeast-3 and/or ca-west-1 for specific rule groups. See security-config.yaml for per-rule regional scope.

#### Global Rules (All OUs + Management)

| Rule | What It Checks | Type | Covers Workload? | Workload Responsibility |
|------|---------------|------|-------------------|-------------------------|
| s3-bucket-server-side-encryption-enabled | S3 buckets have server-side encryption | Detective + Auto-remediation (KMS) | Yes | None — auto-remediated |
| s3-bucket-enforce-https (SSL requests only) | S3 buckets require HTTPS | Detective + Auto-remediation | Yes | None — auto-remediated |
| attach-ec2-instance-profile (custom) | EC2 instances have IAM instance profiles | Detective + Auto-remediation | Yes | None — auto-remediated with default SSM role |
| ec2-instance-profile-permissions (custom) | EC2 instance profiles have required managed policies | Detective + Auto-remediation | Yes | None — auto-remediated |
| elb-logging-enabled | ELB access logging enabled | Detective + Auto-remediation | Yes | None — auto-remediated |

#### All OUs except Sandbox (excludes ap-northeast-3 + ca-west-1)

| Rule | What It Checks | Type | Covers Workload? | Workload Responsibility |
|------|---------------|------|-------------------|-------------------------|
| ebs-in-backup-plan | EBS volumes in backup plan | Detective | Yes | Workload must add EBS volumes to backup plans |
| rds-in-backup-plan | RDS instances in backup plan | Detective | Yes | Workload must add RDS to backup plans |
| internet-gateway-authorized-vpc-only | IGWs attached only to authorized VPCs | Detective | Yes | None — SCP prevents IGW creation |
| ec2-imdsv2-check | EC2 instances use IMDSv2 | Detective + Auto-remediation | Yes | None — auto-remediated |

#### All OUs except Sandbox (excludes ap-northeast-3)

| Rule | What It Checks | Type | Covers Workload? | Workload Responsibility |
|------|---------------|------|-------------------|-------------------------|
| cloudtrail-security-trail-enabled | CloudTrail has security trail | Detective | Yes | None — org trail enabled |
| ec2-instance-detailed-monitoring-enabled | EC2 detailed monitoring enabled | Detective | Yes | Workload should enable detailed monitoring |
| ec2-instances-in-vpc | EC2 instances launched in VPC | Detective | Yes | None — default VPC deleted, only VPC launch possible |
| vpc-sg-open-only-to-authorized-ports | Security groups only allow authorized inbound ports (TCP 443 and UDP 1020-1025) | Detective | Yes | Workload must ensure SGs follow policy |
| sagemaker-notebook-instance-kms-key-configured | SageMaker notebooks use KMS | Detective | Yes | Workload must configure KMS for SageMaker |
| dynamodb-in-backup-plan | DynamoDB tables in backup plan | Detective | Yes | Workload must add DynamoDB to backup plans |
| sagemaker-endpoint-configuration-kms-key-configured | SageMaker endpoints use KMS | Detective | Yes | Workload must configure KMS for endpoints |
| securityhub-enabled | Security Hub is enabled | Detective | Yes | None — enabled by LZA |
| dynamodb-table-encrypted-kms | DynamoDB tables encrypted with KMS | Detective | Yes | Workload must use KMS encryption for DynamoDB |
| guardduty-non-archived-findings | GuardDuty findings are not archived | Detective | Yes | Workload must remediate findings |
| s3-bucket-policy-grantee-check | S3 bucket policies restrict to authorized principals | Detective | Yes | Workload must maintain restrictive bucket policies |
| api-gw-cache-enabled-and-encrypted | API Gateway cache encrypted | Detective | Yes | Workload must enable cache encryption |

#### All OUs except Sandbox (excludes ca-west-1)

| Rule | What It Checks | Type | Covers Workload? | Workload Responsibility |
|------|---------------|------|-------------------|-------------------------|
| redshift-cluster-configuration-check | Redshift encryption + logging enabled | Detective | Yes | Workload must configure encryption and logging |
| iam-user-group-membership-check | IAM users belong to at least one group | Detective | Yes | Workload must assign IAM users to groups |
| cloudtrail-s3-dataevents-enabled | CloudTrail logs S3 data events | Detective | Yes | None — org trail captures S3 data events |
| iam-group-has-users-check | IAM groups have at least one user | Detective | Yes | Workload must clean up empty groups |
| ec2-volume-inuse-check | EBS volumes are attached (delete on termination) | Detective | Yes | Workload must clean up unattached volumes |
| emr-kerberos-enabled | EMR clusters use Kerberos auth | Detective | Yes | Workload must enable Kerberos for EMR |

### Security Hub Standards

| Standard | Status | Scope | Covers Workload? | Workload Responsibility |
|----------|--------|-------|-------------------|-------------------------|
| AWS Foundational Security Best Practices v1.0.0 | Enabled (IAM.1, EC2.10, Lambda.4 disabled) | Organization-wide (delegated to Audit account) | Yes | Workload must remediate findings visible in Security Hub console; define remediation SLAs per organizational policy |
| CIS AWS Foundations Benchmark v3.0.0 | Enabled | Organization-wide | Yes | Workload must remediate findings; CIS checks complement FSBP with identity and logging focus |
| NIST Special Publication 800-53 Revision 5 | Enabled | Organization-wide | Yes | Workload must remediate findings; maps to ITSG-33 control families via CCCS Medium alignment |
| PCI DSS v3.2.1 | Disabled (available to enable) | N/A | No | Enable if workload processes payment data |

## Centralized Services

### Logging and Monitoring

| Service | Scope | Details | Covers Workload? | Workload Responsibility |
|---------|-------|---------|-------------------|-------------------------|
| AWS CloudTrail | Organization trail, all enabled regions | Multi-region org trail with management events, S3 data events, and CloudWatch Logs integration. API call rate insights enabled. Logs delivered to LogArchive S3 bucket. Note: if Control Tower is enabled, managementEvents configuration may differ. | Yes | Workload must configure application-level logging |
| AWS Config | Organization-wide recorder + aggregation | Configuration recorder enabled in all accounts. Aggregated in Audit account. 27 CCCS Medium rules with automated remediation for 5 key rules. | Yes | None — recorder covers all resources |
| CloudWatch Logs | Organization-wide, CMK encrypted | Log retention: [VERIFY — 731 days (2 years) is the default]. Centralized subscription with dynamic partitioning. CloudWatch Logs encrypted with CMK. [VERIFY — CMK encryption is home-region only; confirm encryption scope for ca-west-1.] | Yes | Workload must ship application logs to CloudWatch |
| VPC Flow Logs | Organization-wide | ALL traffic logged to CloudWatch Logs and S3. 30-day CloudWatch retention. Custom fields per network-config.yaml. Covers all VPCs deployed by LZA. | Yes | None — automatically enabled for LZA-managed VPCs |
| Session Manager Logging | Organization-wide (excludes Management, LogArchive, Audit accounts) | Session logs sent to CloudWatch Logs and S3 for audit. | Yes | Workload must use Session Manager for instance access |
| CloudWatch Metric Filters and Alarms | Management account | CIS-aligned metric filters: root account usage, unauthorized API calls, console sign-in without MFA, IAM policy changes, CloudTrail changes, console auth failures, CMK deletion/disable, Config changes, NACL changes, gateway changes, route table changes, VPC changes, SSO/IAM auth from unapproved IPs, unencrypted filesystem creation | Partial | Workload must define application-specific alarms |
| SNS Notification Topics | Management + Audit accounts | SecurityHigh, SecurityMedium, SecurityLow, SecurityIgnore topics with email subscriptions. Security Hub findings at HIGH level route to SecurityHigh. | Partial | Workload must subscribe to relevant topics or create workload-specific topics |
| SSM Inventory | Organization-wide | Systems Manager inventory enabled across all OUs for asset tracking | Yes | None |
| Cost and Usage Report | Management account | Hourly CUR in Parquet format with Athena integration, resource-level detail | Yes | None — covers all accounts via consolidated billing |

### Security Services

| Service | Scope | Details | Covers Workload? | Workload Responsibility |
|---------|-------|---------|-------------------|-------------------------|
| Amazon GuardDuty | Organization-wide, delegated to Audit | S3 protection and EKS protection enabled. Findings exported to S3 every 15 minutes. | Yes | Workload must remediate own findings |
| AWS Security Hub | Organization-wide, delegated to Audit | Region aggregation enabled. FSBP, CIS v3.0.0, and NIST 800-53 r5 standards active. HIGH findings notify SecurityHigh SNS topic. CloudWatch logging enabled. | Yes | Workload must remediate own findings |
| Amazon Macie | Organization-wide, delegated to Audit | Enabled (PII scanning not enabled by default — opt-in). Findings published to Security Hub every 15 minutes. Excludes ca-west-1 (unsupported). For ca-west-1 workloads: implement compensating controls for sensitive data classification (e.g., S3 object tagging, custom Lambda scanners). | Partial | Workload must enable Macie scanning jobs for sensitive data classification |
| Amazon Inspector | Organization-wide | [VERIFY — Inspector is available but check if enabled in your deployment] | Yes | Workload must remediate vulnerabilities found |
| AWS IAM Access Analyzer | Organization-wide | Enabled with Organization as zone of trust. Continuous analysis of resource access patterns and external sharing. | Yes | Workload must remediate own findings |
| AWS Firewall Manager | Organization-wide | [VERIFY — available, SCP protects settings from modification] | Partial | Workload may use for WAF/Shield rule management |
| AWS Audit Manager | Not enabled by default | Disabled in CCCS Medium sample config. Recommended for SA&A evidentiary exercises — can automate evidence collection against NIST 800-53 / ITSG-33 frameworks. | No | Enable if required for SA&A documentation |
| Amazon Detective | Not enabled by default | Disabled in CCCS Medium sample config. Recommended for incident response — provides investigation graphs from CloudTrail, VPC Flow Logs, and GuardDuty findings. | No | Enable if required for IR capability |
| SCP Revert Changes | Organization-wide | Automatically reverts unauthorized SCP modifications. Alerts via SecurityHigh SNS topic. | Yes | None |
| Incident Response | Not configured by default | CCCS Medium does not deploy IR runbooks or automation. Workload must define IR procedures aligned to ITSG-33 IR family controls. | No | Workload must define IR procedures, escalation paths, and containment runbooks |

### Identity

| Service | Scope | Details | Covers Workload? | Workload Responsibility |
|---------|-------|---------|-------------------|-------------------------|
| IAM Identity Center (SSO) | Organization-wide, delegated to Operations account | Centrally managed permission sets and groups. [VERIFY — external IdP integration details] | Yes | Workload must request appropriate permission sets |
| AWS Managed Microsoft AD | Shared to Infrastructure, Central, Dev, Test, Prod, UnClass OUs | [VERIFY — Enterprise edition] hosted in Operations account (Central VPC). Shared via Organizations for centralized Windows/Linux authentication. DNS resolver rules propagated. | Yes | Workload must join instances to domain or use AD for authentication |
| IAM Password Policy | Organization-wide | [VERIFY — Min 14 chars, uppercase + lowercase + symbols + numbers required, 24-password history, 90-day max age, hard expiry enabled. Confirm these values match your iam-config.yaml.] | Yes | None — policy enforced automatically |
| IAM Boundary Policies | Organization-wide (Root OU) | Default boundary policy applied to all EC2/SSM roles. IAM user boundary policy on Management account break-glass users. | Yes | Workload IAM roles should reference the boundary policy |
| Break Glass Users | Management account | Two break-glass IAM users (breakGlassUser01, breakGlassUser02) with AdministratorAccess, scoped by boundary policy | N/A | Emergency use only — workload teams should not use |
| EC2 Default SSM Role | Organization-wide (Root OU) | EC2-Default-SSM-AD-Role with SSM, AD, CloudWatch, Inspector policies. Auto-attached via Config rule remediation. | Yes | None — auto-attached to EC2 instances |
| SSM Public Document Sharing Block | Organization-wide | Prevents sharing SSM documents publicly | Yes | None |

## Network Boundaries

### Connectivity

| Component | Details | Covers Workload? |
|-----------|---------|-------------------|
| Transit Gateway | Hub-and-spoke (Network-Main) in Network account, shared to Infrastructure OU via RAM. Route tables: Core, Segregated, Shared, Standalone. All environment CIDRs (Dev, Test, Prod) blackholed in Segregated route table — mutual isolation between workload environments. | Yes |
| VPC patterns | Standardized VPCs per account: Endpoint VPC (Network account), Perimeter VPC (Perimeter account), Central VPC (Operations account), workload VPCs per tier. Default VPCs deleted across all accounts. | Yes |
| Shared VPC architecture | Network-account-owned VPCs with 3-tier subnets (Web/App/Data) shared to workload OUs via RAM. NACLs restrict Data-tier inbound to App-tier only. | Yes |
| Predefined Security Groups | Management, Web, App, Data SGs pre-created per VPC with least-privilege rules. | Yes |
| VPN / Direct Connect | [VERIFY — on-premises prefix list defined for Central, Dev, Test, Prod, Infrastructure OUs. Configure VPN/DX as needed.] | Partial |
| VPC Endpoints (centralized) | Centralized interface endpoints in Endpoint VPC (Network account): EC2, EC2 Messages, SSM, SSM Messages, KMS, CloudWatch Logs, CloudFormation, Secrets Manager, Monitoring. Gateway endpoints: S3, DynamoDB. Additional endpoints available (commented in config). | Yes |
| IPAM | AWS VPC IPAM with delegated admin in Network account. Sandbox pool provisioned for sandbox environment. | Yes |

### DNS

| Component | Details | Covers Workload? |
|-----------|---------|-------------------|
| Route 53 Resolver (outbound) | Outbound resolver endpoint in Endpoint VPC for forwarding DNS to on-premises (Managed AD domain). Rules shared to Operations account. | Yes |
| Route 53 Resolver Query Logs | Enabled, delivered to S3 and CloudWatch Logs. Shared to Infrastructure OU. | Yes |
| Route 53 Resolver DNS Firewall | Block group with AWS managed botnet/C2 domain list (NODATA response). Shared to Infrastructure OU. | Yes |
| Managed AD DNS | AWS Managed Microsoft AD provides DNS resolution for domain-joined resources. Resolver rule forwards domain queries. | Yes |

### Ingress Controls

| Component | Details | Covers Workload? |
|-----------|---------|-------------------|
| AWS Network Firewall | Centralized in Perimeter VPC (Perimeter account). [VERIFY — stateful rules: blocks Dev/Test to Prod traffic. Confirm stateful rule configuration matches your deployment.] Domain deny list: [ACTION REQUIRED — sample config contains placeholder domain values. Replace with your organization's actual deny list.] Alert logs to S3, flow logs to CloudWatch. | Yes |
| Perimeter ALBs | Public-Prod and Public-DevTest ALBs in Perimeter VPC. HTTPS listeners with TLS policy ELBSecurityPolicy-FS-1-2-Res-2019-08. | Yes |
| Internet Gateway | Only in Perimeter VPC. SCP prevents IGW creation in all other accounts. All internet-bound traffic routes through Perimeter account. | Yes |
| Perimeter VPC architecture | IGW → Network Firewall inspection → NAT Gateway → Transit Gateway → workload VPCs. Inbound traffic inspected by Network Firewall before reaching workloads. | Yes |
| VPC Block Public Access (DCP) | Denies public internet access to VPC resources organization-wide (excludes Perimeter account and Sandbox OU) | Yes |
| AWS Shield | Not configured by CCCS Medium default — Shield Standard is automatic for all accounts; Shield Advanced is not enabled. | Partial |
| AWS WAF | Not configured by CCCS Medium default — available for ALBs, CloudFront, and API Gateway. Recommended for internet-facing workloads. | No |

### Egress Controls

| Component | Details | Covers Workload? |
|-----------|---------|-------------------|
| Centralized NAT Gateway | NAT Gateways in Perimeter VPC (AZ-a and AZ-b). All egress from workload VPCs routes through Transit Gateway to Perimeter. | Yes |
| AWS Network Firewall (egress) | Egress traffic inspected by Network Firewall in Perimeter VPC. Stateful rules and domain deny lists applied. | Yes |
| VPC Endpoint Policies | Default and EC2-specific endpoint policies control traffic through VPC endpoints. | Yes |

## Compliance Baselines

<!-- LZA for CCCS Medium is designed in consultation with CCCS and Treasury Board Secretariat. The CCCS assessment of AWS + LZA sample config addresses up to 70% of ITSG-33 controls with a technical element. -->

> **Scope caveat:** The "up to 70%" figure refers to infrastructure-layer technical controls per ITSG-33 with a technical element, as assessed by CCCS in consultation with Treasury Board Secretariat. Remaining controls require workload-level implementation, operational procedures, and SA&A documentation.

| Framework | Scope | Inherited Controls | Covers Workload? | Workload Responsibility |
|-----------|-------|--------------------|-------------------|-------------------------|
| CCCS Medium Cloud Security Profile (formerly PBMM) | Organization-wide | 162 AWS services assessed in ca-central-1 and ca-west-1. LZA implements infrastructure-layer technical controls for access management, logging, encryption, network segmentation, monitoring, and incident detection aligned to ITSG-33 Annex 3A. | Yes | Workload must implement application-level controls and complete SA&A evidentiary exercise for remaining ~30% of controls |
| NIST 800-53 Rev. 5 | Organization-wide (via Security Hub) | Automated compliance monitoring via Security Hub NIST standard. ITSG-33 is derived from NIST 800-53 Rev. 5 with Canadian-specific modifications — NIST findings map directly to ITSG-33 control families. LZA controls map to AC, AU, CA, CM, CP, IA, IR, PL, RA, SA, SC, SI control families. | Yes | Workload must remediate findings and implement app-level controls |
| CIS AWS Foundations Benchmark v3.0.0 | Organization-wide (via Security Hub) | Automated compliance monitoring. CIS-aligned CloudWatch metric filters and alarms deployed. | Yes | Workload must remediate findings |

### Workload-Specific Compliance Requirements

| Requirement | Scope | Org Coverage | Status | Workload Responsibility |
|-------------|-------|-------------|--------|-------------------------|
| Data residency — Canada only | Organization-wide | Full — Sensitive SCP restricts API calls to approved Canadian regions (ca-central-1, ca-west-1) | Enforced | None — SCP enforces region restriction |
| SA&A (Security Assessment and Authorization) | Workload-specific | Partial — LZA provides ~70% of technical controls | [VERIFY] | Workload team must complete operational controls, SA&A documentation, and evidentiary exercise per ITSP.50.105 |
| [Additional requirements] | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] |

## Shared Resources

| Resource | Details | How Accessed | Required? |
|----------|---------|-------------|-----------|
| Centralized S3 logging bucket | Central log bucket in LogArchive account for CloudTrail, Config, ELB, S3 access logs, and session logs | Automatically delivered by LZA-configured services | Mandatory |
| LZA-managed KMS keys | CMK encryption for S3, CloudWatch Logs, Lambda, SQS across all OUs. Protected by SCP and RCP from modification. | Key policies grant cross-account usage | Mandatory |
| AWS Managed Microsoft AD | Enterprise AD in Operations account, shared to workload OUs | Organization sharing via RAM | Recommended |
| Centralized VPC endpoints | Interface and gateway endpoints in Endpoint VPC (Network account) | Transit Gateway routing from workload VPCs | Mandatory |
| Transit Gateway | Network-Main TGW shared to Infrastructure OU via RAM | Transit Gateway attachment from workload VPCs | Mandatory |
| SSM Automation Documents | ELB logging, S3 encryption, IAM instance profile attachment, IAM role policy attachment, S3 HTTPS enforcement | Shared to all OUs via SSM document sharing | Mandatory |
| IPAM pools | VPC IPAM in Network account with sandbox pool | Shared to Sandbox OU via RAM | Optional |
| On-premises prefix list | Managed prefix list for on-premises CIDR ranges | Shared to Central, Dev, Test, Prod, Infrastructure OUs | Recommended |
| S3 Public Access Block | Account-level S3 Block Public Access enabled across all accounts | Automatically applied by LZA | Mandatory |
| EBS Default Volume Encryption | Default EBS encryption enabled with LZA-managed CMK across all accounts | Automatically applied by LZA | Mandatory |
| Self-signed certificates | Example certificates for Perimeter and Dev accounts | Imported via ACM | [ACTION REQUIRED — replace with proper certificates from your PKI before production use] |

## Backup, Recovery, and Resilience

### Backup Policies

| Setting | Details |
|---------|---------|
| Centralized backup | AWS Backup organizational vault configured by LZA (backup vault provisioned) |
| Backup vault | Organization backup vault with LZA-managed settings |
| Retention policy | Log retention: [VERIFY — 730 days (2 years) for S3 lifecycle, 731 days for CloudWatch Logs. Confirm both values match your global-config.yaml and security-config.yaml. Backup vault retention per your deployment. Treasury Board guidance recommends considering 10-year retention.] |
| Testing frequency | [VERIFY — define restore test cadence per organizational policy] |
| Cross-region replication | [VERIFY — configure if multi-region DR is required. LZA supports ca-central-1 and ca-west-1.] |

### Disaster Recovery and Resilience

| Setting | Details |
|---------|---------|
| RTO target | [VERIFY — define per workload tier] |
| RPO target | [VERIFY — define per workload tier] |
| Multi-AZ strategy | LZA deploys subnets across AZ-a and AZ-b for all VPCs. Network Firewall, NAT Gateways, and endpoints span 2 AZs. Workload must deploy across AZs. |
| Multi-Region strategy | LZA supports ca-central-1 (primary) and ca-west-1 (secondary). [VERIFY — active-passive or single region per your deployment] |
| Failover automation | [VERIFY — configure Route 53 health checks and failover if multi-region] |
| Resilience Hub | [VERIFY — enroll if applicable] |

## Cost Governance

| Setting | Details |
|---------|---------|
| Consolidated billing | Yes — single payer (Management account) with all workload accounts |
| RI / Savings Plans | [VERIFY — configure organization-wide Compute Savings Plans per FinOps policy] |
| Budgets | AWS Budgets configured: [VERIFY — Network ($2,000/mo), Perimeter ($2,000/mo), Management ($10,000/mo), all other accounts ($1,000/mo default). Confirm amounts match your global-config.yaml.] Alerts at 50%, 75%, 80%, 90%, 100% thresholds via email. |
| Cost Anomaly Detection | [VERIFY — enable if not configured] |
| Chargeback / showback | Cost and Usage Report (CUR) enabled — hourly Parquet format with Athena integration and resource-level detail |
| Cost allocation tags | Accelerator tag applied to LZA resources. [VERIFY — activate additional tags: CostCenter, Project, Environment, Owner] |

## Change Management

| Setting | Details |
|---------|---------|
| Deployment tooling | LZA CodePipeline (CDK-based) — infrastructure changes deployed via pipeline from config files in CodeCommit/S3. Workload deployments are per-team. |
| Deployment guardrails | SCP revert changes enabled — unauthorized modifications to LZA-managed SCPs are automatically reverted with SecurityHigh notification |
| Approval gates | [VERIFY — define approval requirements for production deployments] |
| Change windows | [VERIFY — define production change windows per organizational policy] |
| Runbooks | SSM Automation documents deployed organization-wide for common remediation tasks. [VERIFY — additional runbooks per operational requirements] |

## Operational Context

### Tagging Strategy

- **Required tags:** Accelerator tag applied to all LZA-managed resources. [VERIFY — define additional mandatory tags: Environment, Project, CostCenter, Owner]
- **Enforcement:** [VERIFY — Tag policies available but not configured in sample config (taggingPolicies: []). Implement tag policies per organizational requirements.]

### Patching

- **Managed patching:** Systems Manager with SSM Inventory enabled across all OUs. EC2-Default-SSM-AD-Role provides SSM Managed Instance Core access for all EC2 instances. [VERIFY — configure Patch Manager baselines and maintenance windows.]
- **Patch windows:** [VERIFY — define maintenance windows per organizational policy]

---

## Workload Team Action Summary

### ACTION REQUIRED (resolve before production)

- **Self-signed certificates** — replace example certificates in Perimeter and Dev accounts with proper certificates from your PKI (Shared Resources)
- **Network Firewall domain deny list** — replace placeholder domain values with your organization's actual deny list (Ingress Controls)
- **IP filter placeholders** — review and replace any placeholder IP ranges in security group rules and NACL entries

### VERIFY (confirm values match your deployment)

- **LZA config version** — insert your LZA version and CCCS Medium config commit/tag (Header)
- **OU names** — confirm Central / Dev / Test / Prod / UnClass / Sandbox match your organization-config.yaml (Account Structure)
- **RCP/DCP deployment** — confirm whether RCPs and DCPs are deployed in your LZA version (Inheritable Controls)
- **Network Firewall stateful rules** — confirm rule configuration matches your deployment (Ingress Controls)
- **IAM password policy values** — confirm min length, history, max age match your iam-config.yaml (Identity)
- **AD edition** — confirm Enterprise edition matches your deployment (Identity)
- **CMK encryption scope** — confirm home-region-only scope and ca-west-1 coverage (Logging)
- **Log retention** — confirm 730 days (S3) and 731 days (CloudWatch) match your config (Backup)
- **Budget amounts** — confirm Network, Perimeter, Management, default amounts (Cost Governance)
- **Inspector enablement** — check if enabled in your deployment (Security Services)

### Ongoing Responsibilities

- Remediate Security Hub findings per standard (FSBP, CIS, NIST) with defined SLAs
- Add workload resources to AWS Backup plans (EBS, RDS, DynamoDB, Aurora)
- Ship application logs to CloudWatch Logs
- Define application-specific CloudWatch alarms
- Use Session Manager for instance access (audit trail)
- Maintain restrictive S3 bucket policies and security group rules
- Complete SA&A evidentiary exercise per ITSP.50.105
- Define IR procedures, escalation paths, and containment runbooks

---

## Appendix A: LZA CCCS Medium Compliance Coverage

LZA with the CCCS Medium sample configuration maps to the following ITSG-33 control families (non-exhaustive).

> **Rating scale:** **Extensive** = multiple overlapping technical controls, auto-remediation, and monitoring. **Moderate** = technical controls present but workload action needed for full coverage. **Limited** = foundational infrastructure support only; workload must implement most controls.

| Control Family | LZA Coverage | Key Mechanisms |
|----------------|-------------|----------------|
| AC (Access Control) | Extensive | SCPs, RCPs, IAM policies, boundary policies, SG rules, NACL, VPC Block Public Access |
| AU (Audit and Accountability) | Extensive | CloudTrail org trail, Config recorder, CloudWatch Logs, Session Manager logging, centralized S3 log archive |
| CA (Security Assessment) | Moderate | Security Hub standards, Config rules, GuardDuty, Access Analyzer |
| CM (Configuration Management) | Extensive | SCPs protect LZA resources, Config rules with auto-remediation, SSM Inventory |
| CP (Contingency Planning) | Moderate | Backup vault, backup Config rules, multi-AZ deployment |
| IA (Identification and Authentication) | Moderate | IAM Identity Center, Managed AD, password policy, MFA monitoring |
| IR (Incident Response) | Moderate | GuardDuty, Security Hub findings, SNS notifications, CloudWatch alarms |
| PL (Planning) | Limited | Organization structure, centralized management |
| RA (Risk Assessment) | Limited | Security Hub findings, GuardDuty threat detection, Config compliance dashboards |
| SA (System and Services Acquisition) | Limited | SCPs enforce change control; secure development practices are workload responsibility |
| SC (System and Communications Protection) | Extensive | Encryption (EBS, S3, CloudWatch, Lambda, SQS, KMS CMKs), TLS enforcement (RCPs), Network Firewall, Transit Gateway segmentation, VPC endpoints |
| SI (System and Information Integrity) | Extensive | GuardDuty, Security Hub, Macie, Config rules, CloudWatch metric filters and alarms |

## Appendix B: CCCS Medium Assessed Services

As of September 12, 2025, 162 AWS services in the Canadian regions (ca-central-1 and ca-west-1) are assessed by CCCS and meet CCCS Medium requirements. Key services include:

- **Compute:** EC2, Lambda, ECS, EKS, Fargate, Batch, Elastic Beanstalk
- **Storage:** S3, EBS, EFS, FSx, S3 Glacier, Storage Gateway
- **Database:** RDS, Aurora, DynamoDB, ElastiCache, DocumentDB, Neptune, Redshift, MemoryDB
- **Networking:** VPC, Transit Gateway, Route 53, CloudFront, Direct Connect, Network Firewall, WAF, Shield, PrivateLink, VPC Lattice, Global Accelerator
- **Security:** IAM, KMS, CloudHSM, Secrets Manager, Security Hub, GuardDuty, Inspector, Macie, Detective, Access Analyzer, Firewall Manager, Certificate Manager, Private CA
- **Management:** Organizations, Control Tower, CloudTrail, Config, CloudWatch, Systems Manager, Service Catalog, Backup, Audit Manager
- **AI/ML:** Bedrock, SageMaker AI, Comprehend, Rekognition, Textract, Transcribe, Translate, Lex, Polly, Personalize, Kendra
- **Developer Tools:** CodePipeline, CodeBuild, CodeCommit, CodeDeploy, CloudFormation, Cloud9, X-Ray
- **Analytics:** Athena, EMR, Glue, Kinesis, OpenSearch, Quick Suite, Lake Formation, DataZone

For the complete list, see [AWS Services in Scope for CCCS Assessment](https://aws.amazon.com/compliance/services-in-scope/CCCS/).

## Appendix C: Data Collection Verification Guide

Use this guide to verify that your LZA deployment matches this profile.

| Section | How to Verify |
|---------|---------------|
| Account Structure | `aws organizations list-accounts` and `aws organizations list-organizational-units-for-parent` |
| SCPs | `aws organizations list-policies --filter SERVICE_CONTROL_POLICY` then review each policy |
| Config Rules | `aws configservice describe-config-rules` in each account/region |
| Security Hub | `aws securityhub get-enabled-standards` |
| GuardDuty | `aws guardduty list-detectors` then `aws guardduty get-detector` |
| Macie | `aws macie2 get-macie-session` |
| CloudTrail | `aws cloudtrail describe-trails` |
| Network | `aws ec2 describe-transit-gateways`, `aws ec2 describe-vpcs`, `aws networkfirewall list-firewalls` |
| IAM | `aws iam get-account-authorization-details` for roles and policies |
| Backup | `aws backup list-backup-plans` and `aws backup list-backup-vaults` |
| Budgets | `aws budgets describe-budgets --account-id <mgmt-account-id>` |

## Appendix D: Recommended Additional Config Rules

> **Note:** The following Config rules are available in the broader LZA Universal Configuration but are NOT deployed by the CCCS Medium sample configuration by default. Consider enabling them based on your workload requirements. [VERIFY — check your security-config.yaml to confirm which rules are active in your deployment.]

| Rule | What It Checks | Workload Responsibility |
|------|---------------|-------------------------|
| iam-no-inline-policy-check | No inline IAM policies | Workload must use managed policies, not inline |
| account-part-of-organizations | Account is part of Organization | None |
| codebuild-project-artifact-encryption | CodeBuild artifacts encrypted | Workload must encrypt CodeBuild artifacts |
| dynamodb-throughput-limit-check | DynamoDB approaching throughput limits | Workload must monitor capacity |
| ebs-optimized-instance | EC2 instances are EBS-optimized | Workload should use EBS-optimized instances |
| lambda-dlq-check | Lambda functions have DLQ configured | Workload must configure DLQs for Lambda |
| secretsmanager-using-cmk | Secrets Manager uses CMK | Workload must use CMK for secrets |
| aurora-resources-protected-by-backup-plan | Aurora in backup plan | Workload must add Aurora to backup plans |
| backup-plan-min-frequency-and-min-retention-check | Backup plans meet frequency/retention minimums | Workload must configure adequate backup plans |
| backup-recovery-point-manual-deletion-disabled | Recovery points protected from manual deletion | Workload must enable vault lock / deletion protection |
| backup-recovery-point-encrypted | Recovery points encrypted | Workload must use encrypted backups |
| ec2-resources-protected-by-backup-plan | EC2 instances in backup plan | Workload must add EC2 to backup plans |

## Appendix E: Acronym Glossary

| Acronym | Definition |
|---------|-----------|
| ACM | AWS Certificate Manager |
| ALB | Application Load Balancer |
| CCCS | Canadian Centre for Cyber Security |
| CMK | Customer Managed Key (AWS KMS) |
| CT | AWS Control Tower |
| CUR | Cost and Usage Report |
| DCP | Declarative Control Policy |
| DLQ | Dead Letter Queue |
| DX | AWS Direct Connect |
| FSBP | AWS Foundational Security Best Practices |
| IGW | Internet Gateway |
| IMDSv2 | Instance Metadata Service Version 2 |
| IPAM | IP Address Manager |
| IR | Incident Response |
| ITSG-33 | Information Technology Security Guidance Publication 33 (Canadian government) |
| ITSP.50.105 | Information Technology Security Publication — SA&A guidance |
| LZA | Landing Zone Accelerator on AWS |
| NACL | Network Access Control List |
| NLB | Network Load Balancer |
| OU | Organizational Unit |
| PBMM | Protected B, Medium Integrity, Medium Availability (former CCCS Medium name) |
| PKI | Public Key Infrastructure |
| RAM | AWS Resource Access Manager |
| RCP | Resource Control Policy |
| SA&A | Security Assessment and Authorization |
| SCP | Service Control Policy |
| SG | Security Group |
| SSM | AWS Systems Manager |
| SSO | Single Sign-On (now IAM Identity Center) |
| TGW | Transit Gateway |
| TLS | Transport Layer Security |
| VPC | Virtual Private Cloud |
| WAF | Web Application Firewall |
