# ADR-0004: EC2 in a public subnet (ALB + private subnet as stretch)

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

The reference diagram puts the app server in a public subnet. A stronger pattern puts a load balancer in the public subnets and the app in private subnets. That adds cost (an ALB is ~$16+ per month), and without a NAT Gateway it also needs interface endpoints for SSM, Secrets Manager and Logs.

## Decision

Run the EC2 app server in a public subnet, with its exposure kept as small as possible:

- The security group allows inbound **443 only**. Outbound is limited to 443, and 3306 to the RDS security group.
- No SSH (ADR-0003), IMDSv2 required with a hop limit of 1, and an encrypted EBS volume.
- A narrowly scoped instance role, capped by a permissions boundary.

**ALB + WAF + private app subnet + interface endpoints** is documented as the hardening stretch goal.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **EC2 public, 443 only (chosen)** | Cheap; simple; matches the diagram | Instance directly reachable; self-signed certificate |
| ALB public + EC2 private | Instance not directly reachable; ACM certificate; WAF possible | ALB cost; needs interface endpoints (no NAT) |
| API Gateway + Lambda | No servers to manage | Changes the architecture being demonstrated |

## Consequences

- The residual risk is recorded in the [threat model](../threat-model.md#residual-risks-accepted-for-a-dev-portfolio-environment).
- A compromised app only gets the scoped role's permissions, which the least-privilege evidence demonstrates.
