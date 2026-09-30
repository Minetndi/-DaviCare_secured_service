# ADR-0003: SSM Session Manager instead of SSH

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Admins need shell access to the app server. SSH needs port 22 open and SSH keys that have to be distributed and rotated, and its audit trail is weak.

## Decision

- No inbound port 22 and no EC2 key pair.
- Admin access goes through **AWS Systems Manager Session Manager** and is allowed only for the break-glass admin role, which requires MFA.
- The instance role includes `AmazonSSMManagedInstanceCore`.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| SSH with a key pair, restricted to one IP | Familiar | Open port; key management; home IPs change; weak audit |
| Bastion host | Standard pattern | Extra instance and cost; still SSH |
| EC2 Instance Connect | Short-lived keys | Still needs port 22 |
| **SSM Session Manager (chosen)** | No open ports; controlled by IAM + MFA; audited in CloudTrail | Needs the SSM agent and outbound 443 to SSM endpoints |

## Consequences

- Verification: `nc -vz <ip> 22` is refused, `aws ssm start-session` succeeds, and the session appears in CloudTrail.
- If the instance loses its route to the SSM endpoints, admin access is lost. Recovery is to replace the instance with Terraform.
