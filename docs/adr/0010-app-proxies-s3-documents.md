# ADR-0010: App proxies S3 document transfers

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

The first plan handed pre-signed S3 URLs to the client. The vault bucket policy denies any request that doesn't come through the VPC gateway endpoint (`aws:SourceVpce`). A pre-signed URL used from a client's browser arrives from the internet, so S3 would deny it. Loosening the policy would weaken a core control.

## Decision

The FastAPI app streams uploads and downloads between the client and S3. Only the app, which runs inside the VPC, talks to S3. It uses its instance role and goes through the gateway endpoint. Objects are written with SSE-KMS using `davicare-data`.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Pre-signed URLs + relax the VPCE condition | Takes the transfer load off the app | Anyone with a valid URL could reach the vault from the internet |
| **App proxies transfers (chosen)** | Keeps the VPCE-only guarantee; the app audits every access | The app handles file bytes, which is fine at demo sizes |
| CloudFront + OAC | Scalable delivery | An extra service that complicates the demonstration |

## Consequences

- Verification: a request to the vault from outside the VPC returns `AccessDenied`, even with valid admin credentials (break-glass excepted).
- The app enforces a file size limit.
