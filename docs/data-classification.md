# Data Classification

All data in this project is **synthetic**. It's still classified and handled as if it were real protected health information (PHI), so the controls are exercised realistically.

## Classification levels

| Level | Definition | Examples in this project |
|---|---|---|
| **Restricted (PHI)** | Identifies a patient, or links a person to health information | Mother/child names, dates of birth, addresses, phone numbers, pregnancy and delivery details, child growth and vaccination records, uploaded clinical documents |
| **Confidential** | Not PHI, but would help an attacker or expose internals | DB credentials, KMS key IDs combined with policies, Terraform state, CloudTrail logs, Flow Logs, internal hostnames |
| **Internal** | Operational data with no patient content | Opaque record IDs (UUIDs), audit events without PHI, metrics, alarm names |
| **Public** | Safe to publish | Terraform code, documentation, architecture diagrams, redacted evidence screenshots |

## Where each level may live

| Location | Restricted (PHI) | Confidential | Internal | Public |
|---|---|---|---|---|
| RDS MySQL | ✅ | – | ✅ | – |
| S3 data vault (`records/*`) | ✅ | – | – | – |
| Secrets Manager | – | ✅ | – | – |
| Terraform state bucket | ❌ | ✅ | ✅ | – |
| CloudWatch app logs | ❌ | ❌ | ✅ | – |
| CloudTrail / Flow Logs buckets | ❌ | ✅ | ✅ | – |
| EC2 local disk | ❌ (in memory only) | ❌ | ✅ | – |
| Git repository | ❌ | ❌ | – | ✅ |
| Resource tags, names, descriptions | ❌ | ❌ | ✅ | ✅ |
| Bedrock prompts (future) | Only after Guardrails masking, and only data the caller may already read | ❌ | ✅ | – |
| `docs/evidence/` | ❌ (redact) | ❌ (redact account IDs and ARNs where sensible) | ✅ | ✅ |

✅ allowed · ❌ must never appear · – not applicable

## Handling rules

1. **Synthetic only.** Every generated record carries a `SYNTHETIC` marker. Loading real data is out of scope and would need a BAA, a separate account and a review of this document.
2. **Encryption.** Restricted data is encrypted at rest with the `davicare-data` CMK and in transit with TLS 1.2 or later.
3. **Logs are PHI-free.** App audit events contain `actor`, `action`, `record_id`, `timestamp` and `result` only. Exception messages are sanitized before logging.
4. **No secrets in code or state.** Credentials come from Secrets Manager at runtime. Terraform uses RDS-managed master passwords so no password is ever in variables or state.
5. **Identifiers.** Records are referenced by random UUIDs. Names and dates of birth are never used in S3 keys, URLs or log fields.
6. **Retention.** Non-current S3 object versions expire under a lifecycle rule. Log groups have explicit retention periods. Everything is removed by `terraform destroy` at the end of a demo.
7. **Evidence.** Screenshots are reviewed before committing. Account IDs, emails and any record content are redacted.
