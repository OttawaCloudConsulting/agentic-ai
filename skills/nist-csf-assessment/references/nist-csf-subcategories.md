<!-- version: 2.0 -->
# NIST CSF 2.0 Subcategories

## Source of Truth

Subcategories are defined in the [NIST Cybersecurity Framework 2.0 (CSWP 29)](https://csrc.nist.gov/pubs/cswp/29/final). The authoritative subcategory list with 800-53 informative references is maintained in the [CSF 2.0 Reference Tool](https://csrc.nist.gov/projects/cybersecurity-framework/filters).

Phase 0 of the nist-csf-assessment skill validates the version recorded in this file against the current published version on the NIST CSF landing page. If a newer version is available, Phase 0 overwrites this file with updated content before assessment begins.

800-53 informative references in this file are native to CSF 2.0. They map each subcategory outcome to the corresponding NIST SP 800-53 Rev 5 controls.

## Contents

- [GV — Govern](#gv--govern) (OC, RM, RR, PO, OV, SC)
- [ID — Identify](#id--identify) (AM, RA, IM)
- [PR — Protect](#pr--protect) (AA, AT, DS, PS, IR)
- [DE — Detect](#de--detect) (CM, AE)
- [RS — Respond](#rs--respond) (MA, AN, CO, MI)
- [RC — Recover](#rc--recover) (RP, CO)

---

## GV — Govern

Establishes and monitors the organization's cybersecurity risk management strategy, expectations, and policy.

### GV.OC — Organizational Context

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| GV.OC-01 | The organizational mission is understood and informs cybersecurity risk management | PM-11, SA-2 |
| GV.OC-02 | Internal and external stakeholders are understood, and their needs and expectations regarding cybersecurity risk management are understood and considered | PM-2, PM-11 |
| GV.OC-03 | Legal, regulatory, and contractual requirements regarding cybersecurity — including privacy and civil liberties obligations — are understood and managed | PM-13, PL-1, SA-9 |
| GV.OC-04 | Critical objectives, capabilities, and services that stakeholders depend on or expect from the organization are understood and communicated | PM-11, SA-14, RA-9 |
| GV.OC-05 | Outcomes, capabilities, and services that the organization depends on are understood and communicated | PM-11, RA-9, SA-12 |

### GV.RM — Risk Management Strategy

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| GV.RM-01 | Risk management objectives are established and agreed to by organizational stakeholders | PM-9, PM-28 |
| GV.RM-02 | Risk appetite and risk tolerance statements are established, communicated, and maintained | PM-9 |
| GV.RM-03 | Organizational cybersecurity risk management is informed by and integrated into the enterprise risk management (ERM) framework | PM-9, PM-28 |
| GV.RM-04 | Strategic direction that describes appropriate risk response options is established and communicated | PM-9 |
| GV.RM-05 | Lines of communication across the organization are established for cybersecurity risks, including risks from suppliers and other third parties | PM-9, PM-30 |
| GV.RM-06 | A standardized method for calculating, documenting, categorizing, and prioritizing cybersecurity risks is established and communicated | PM-9, RA-3 |
| GV.RM-07 | Strategic opportunities (i.e., positive risks) are characterized and are included in organizational cybersecurity risk discussions | PM-9 |

### GV.RR — Roles, Responsibilities, and Authorities

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| GV.RR-01 | Organizational leadership is responsible and accountable for cybersecurity risk and fosters a culture that is risk-aware, ethical, and continually improving | PM-2, PM-3 |
| GV.RR-02 | Roles, responsibilities, and authorities related to cybersecurity risk management are established, communicated, understood, and enforced | PM-2, PS-7 |
| GV.RR-03 | Adequate resources are allocated commensurate with the cybersecurity risk strategy, roles, responsibilities, and policies | PM-3 |
| GV.RR-04 | Cybersecurity is included in human resources practices | PS-7, SA-21 |

### GV.PO — Policy

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| GV.PO-01 | Policy for managing cybersecurity risks is established based on organizational context, cybersecurity strategy, and priorities and is communicated and enforced | PM-1, PL-1 |
| GV.PO-02 | Policy for managing cybersecurity risks is reviewed, updated, communicated, and enforced to reflect changes in requirements, threats, technology, and organizational mission | PM-1, PL-1 |

### GV.OV — Oversight

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| GV.OV-01 | Cybersecurity risk management strategy outcomes are reviewed to inform and adjust strategy and direction | PM-9 |
| GV.OV-02 | The cybersecurity risk management strategy is reviewed and adjusted to ensure coverage of organizational requirements and risks | PM-9, CA-7 |
| GV.OV-03 | Organizational cybersecurity risk management performance is evaluated and reviewed for adjustments needed | PM-9, CA-7 |

### GV.SC — Cybersecurity Supply Chain Risk Management

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| GV.SC-01 | A cybersecurity supply chain risk management program, strategy, objectives, policies, and processes are established and agreed to by organizational stakeholders | PM-30, SA-9 |
| GV.SC-02 | Cybersecurity roles and responsibilities for suppliers, customers, and partners are established, communicated, and coordinated internally and externally | PM-30, SA-9, PS-7 |
| GV.SC-03 | Cybersecurity supply chain risk management is integrated into cybersecurity and enterprise risk management, risk assessment, and improvement processes | PM-30, RA-3 |
| GV.SC-04 | Suppliers are known and prioritized by criticality | PM-30, RA-9, SA-12 |
| GV.SC-05 | Requirements to address cybersecurity risks in supply chains are established, prioritized, and integrated into contracts and other types of agreements with suppliers and other relevant third parties | PM-30, SA-4, SA-9 |
| GV.SC-06 | Planning and due diligence are performed to reduce risks before entering into formal supplier or other third-party relationships | PM-30, SA-4 |
| GV.SC-07 | The risks posed by a supplier, their products and services, and other third parties are understood, recorded, prioritized, assessed, responded to, and monitored over the course of the relationship | PM-30, RA-3, SA-9 |
| GV.SC-08 | Relevant suppliers and other third parties are included in incident planning, response, and recovery activities | PM-30, CP-2, IR-4 |
| GV.SC-09 | Supply chain security practices are integrated into cybersecurity and enterprise risk management programs, and their performance is monitored throughout the technology product and service life cycle | PM-30, CA-7, SA-9 |
| GV.SC-10 | Cybersecurity supply chain risk management plans include provisions for activities that occur after the conclusion of a partnership or support agreement | PM-30, SA-9 |

---

## ID — Identify

Helps the organization understand its current cybersecurity risk to systems, people, assets, data, and capabilities.

### ID.AM — Asset Management

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| ID.AM-01 | Inventories of hardware managed by the organization are maintained | CM-8, PM-5 |
| ID.AM-02 | Inventories of software, services, and systems managed by the organization are maintained | CM-8, PM-5 |
| ID.AM-03 | Representations of the organization's authorized network communication and internal and external network data flows are maintained | AC-4, CA-3, CM-2, SA-9 |
| ID.AM-04 | Inventories of services provided by suppliers are maintained | PM-30, SA-9 |
| ID.AM-05 | Assets are prioritized based on classification, criticality, resources, and impact on the mission | CM-8, PM-5, RA-2, SA-14 |
| ID.AM-07 | Inventories of data and corresponding metadata for designated data types are maintained | CM-8, PM-5 |
| ID.AM-08 | Systems, hardware, software, services, and data are managed throughout their life cycles | CM-8, PM-5, SA-3 |

### ID.RA — Risk Assessment

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| ID.RA-01 | Vulnerabilities in assets are identified, validated, and recorded | CA-2, CA-7, RA-3, RA-5, SI-2 |
| ID.RA-02 | Cyber threat intelligence is received from information sharing forums and sources | PM-16, SI-5 |
| ID.RA-03 | Internal and external threats to the organization are identified and recorded | RA-3, SI-5, PM-12 |
| ID.RA-04 | Potential impacts and likelihoods of threats exploiting vulnerabilities are identified and recorded | RA-3 |
| ID.RA-05 | Threats, vulnerabilities, likelihoods, and impacts are used to understand inherent risk and inform risk response prioritization | RA-3, PM-28 |
| ID.RA-06 | Risk responses are chosen, prioritized, planned, tracked, and communicated | PM-9, RA-3 |
| ID.RA-07 | Changes and exceptions are managed, assessed for risk impact, authorized, and documented | CA-7, CM-3, RA-3 |
| ID.RA-08 | Processes for receiving, analyzing, and responding to vulnerability disclosures are established | RA-5, IR-6, SI-5 |
| ID.RA-09 | The authenticity and integrity of hardware and software are assessed prior to acquisition and use | SR-4, SR-9, SA-10 |
| ID.RA-10 | Critical suppliers are assessed prior to acquisition | SR-3, SA-4, PM-30 |

### ID.IM — Improvement

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| ID.IM-01 | Improvements are identified from evaluations | CA-2, CA-7, CP-4, IR-3 |
| ID.IM-02 | Improvements are identified from security tests and exercises, including those done in coordination with suppliers and relevant third parties | CA-2, CA-7, CP-4, IR-3 |
| ID.IM-03 | Improvements are identified from execution of operational processes, procedures, and activities | CA-7, CP-4, IR-3 |
| ID.IM-04 | Incident, vulnerability, and other cybersecurity risk information is communicated to the teams responsible for the products and services being protected | IR-6, RA-5, SI-2 |

---

## PR — Protect

Safeguards to manage the organization's cybersecurity risk.

### PR.AA — Identity Management, Authentication, and Access Control

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| PR.AA-01 | Identities and credentials for authorized users, services, and hardware are managed by the organization | AC-2, IA-2, IA-4, IA-5 |
| PR.AA-02 | Identities are proofed and bound to credentials based on the context of interactions | IA-3, IA-12 |
| PR.AA-03 | Users, services, and hardware are authenticated | IA-2, IA-3, IA-8 |
| PR.AA-04 | Identity assertions are protected, conveyed, and verified | IA-2, IA-5, IA-8, SC-8 |
| PR.AA-05 | Access permissions, entitlements, and authorizations are defined in a policy, managed, enforced, and reviewed | AC-2, AC-3, AC-5, AC-6 |
| PR.AA-06 | Physical access to assets is managed, monitored, and enforced commensurate with risk | PE-2, PE-3, PE-6 |

### PR.AT — Awareness and Training

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| PR.AT-01 | Personnel are provided with awareness and training so that they possess the knowledge and skills to perform general tasks with cybersecurity risks in mind | AT-2, AT-3 |
| PR.AT-02 | Individuals in specialized roles are provided with awareness and training so that they possess the knowledge and skills to perform relevant tasks with cybersecurity risks in mind | AT-3 |

### PR.DS — Data Security

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| PR.DS-01 | The confidentiality, integrity, and availability of data-at-rest are protected | SC-28, SI-12 |
| PR.DS-02 | The confidentiality, integrity, and availability of data-in-transit are protected | SC-8, SC-28 |
| PR.DS-10 | The confidentiality, integrity, and availability of data-in-use are protected | SC-4, AC-3 |
| PR.DS-11 | Backups of data are created, protected, maintained, and tested | CP-9, CP-10 |

### PR.PS — Platform Security

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| PR.PS-01 | Configuration management practices are established and applied | CM-2, CM-6, CM-7, CM-9 |
| PR.PS-02 | Software is maintained, replaced, and removed commensurate with risk | CM-3, SI-2, SA-22 |
| PR.PS-03 | Hardware is maintained, replaced, and removed commensurate with risk | CM-8, MA-2 |
| PR.PS-04 | Log records are generated and made available for continuous monitoring | AU-2, AU-3, AU-6, AU-12 |
| PR.PS-05 | Installation and execution of unauthorized software are prevented | CM-7, CM-10, SI-3 |
| PR.PS-06 | Secure software development practices are integrated, and their performance is monitored throughout the software development life cycle | SA-3, SA-8, SA-11, SA-15 |

### PR.IR — Technology Infrastructure Resilience

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| PR.IR-01 | Networks and environments are protected from unauthorized logical access and usage | AC-3, AC-4, SC-7 |
| PR.IR-02 | The organization's technology assets are protected from environmental threats | PE-9, PE-12, PE-13 |
| PR.IR-03 | Mechanisms are implemented to achieve resilience requirements in normal and adverse situations | CP-2, CP-7, CP-10 |
| PR.IR-04 | Adequate resource capacity to ensure availability is maintained | CP-2, SC-5, AU-9 |

---

## DE — Detect

Identifies the occurrence of a cybersecurity event.

### DE.CM — Continuous Monitoring

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| DE.CM-01 | Networks and network services are monitored to find potentially adverse events | AU-2, AU-12, CA-7, SI-4 |
| DE.CM-02 | The physical environment is monitored to find potentially adverse events | PE-6 |
| DE.CM-03 | Personnel activity and technology usage are monitored to find potentially adverse events | AC-2, AU-12, CA-7, SI-4 |
| DE.CM-06 | External service provider activities and services are monitored to find potentially adverse events | CA-7, PS-7, SA-9 |
| DE.CM-09 | Computing hardware and software, runtime environments, and their data are monitored to find potentially adverse events | AU-2, AU-12, CA-7, SI-4 |

### DE.AE — Adverse Event Analysis

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| DE.AE-02 | Potentially adverse events are analyzed to better understand associated activities | CA-7, IR-4, SI-4 |
| DE.AE-03 | Information is correlated from multiple sources | CA-7, IR-4, SI-4 |
| DE.AE-04 | The estimated impact and scope of adverse events are understood | CA-7, IR-4, RA-3 |
| DE.AE-06 | Information on adverse events is provided to authorized staff and tools | CA-7, IR-6, SI-4 |
| DE.AE-07 | Cyber threat intelligence and other contextual information are integrated into the analysis of adverse events | IR-4, RA-3, SI-4 |
| DE.AE-08 | Incidents are declared when adverse events meet the defined incident criteria | IR-4, IR-5 |

---

## RS — Respond

Takes action regarding a detected cybersecurity incident.

### RS.MA — Incident Management

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| RS.MA-01 | The incident response plan is executed in coordination with relevant third parties once an incident is declared | IR-4, IR-8 |
| RS.MA-02 | Incident reports are triaged and validated | IR-4, IR-5 |
| RS.MA-03 | Incidents are categorized and prioritized | IR-4, IR-5 |
| RS.MA-04 | Incidents are escalated or elevated as needed | IR-4 |
| RS.MA-05 | The criteria for initiating incident recovery are applied | IR-4, CP-10 |

### RS.AN — Incident Analysis

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| RS.AN-03 | Analysis is performed to establish what has taken place during an incident and the root cause of the incident | IR-4 |
| RS.AN-06 | Actions performed during an investigation are recorded, and the records' integrity and provenance are preserved | AU-9, IR-4 |
| RS.AN-07 | Incident cause is determined and documented | IR-4 |
| RS.AN-08 | Incidents are catalogued and used to inform the improvement of cybersecurity practices | IR-4, IR-8 |

### RS.CO — Incident Response Reporting and Communication

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| RS.CO-02 | Internal and external stakeholders are notified of incidents in a timely manner as required | IR-6 |
| RS.CO-03 | Information is shared with designated internal and external stakeholders as required | IR-6, SI-5 |
| RS.CO-04 | Coordination with stakeholders occurs consistent with incident response plans | IR-4, IR-8 |

### RS.MI — Incident Mitigation

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| RS.MI-01 | Incidents are contained | IR-4 |
| RS.MI-02 | Incidents are eradicated | IR-4 |

---

## RC — Recover

Restores assets and operations that were impacted by a cybersecurity incident.

### RC.RP — Incident Recovery Plan Execution

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| RC.RP-01 | The recovery portion of the incident response plan is executed once initiated from the incident response process | CP-10, IR-4 |
| RC.RP-02 | Recovery actions are selected, scoped, prioritized, and performed | CP-10, IR-4 |
| RC.RP-03 | The integrity of backups and other restoration assets is verified before using them for restoration | CP-9, IR-4 |
| RC.RP-04 | Critical mission functions and cybersecurity risk management are considered to establish post-incident operational norms | CP-2, CP-10, IR-4 |
| RC.RP-05 | The integrity of restored assets is verified, systems and services are restored, and normal operating status is confirmed | CP-10, SI-12 |
| RC.RP-06 | The end of incident recovery is declared based on criteria, and incident-related documentation is completed | CP-10, IR-4 |

### RC.CO — Incident Recovery Communication

| Subcategory | Outcome Statement | Key 800-53 Informative References |
|---|---|---|
| RC.CO-03 | Recovery activities and progress in restoring operational capabilities are communicated to designated internal and external stakeholders | CP-2, IR-4 |
| RC.CO-04 | Public updates on incident recovery are shared using approved methods and messaging | CP-2, IR-4 |
