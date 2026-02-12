# Security Policy

This repository contains governance-critical smart contract code intended for production deployment.

## Reporting a Vulnerability

If you find a security issue, do not open a public issue. Report privately to the maintainers and include:

- Impact and exploit scenario
- Affected functions/paths
- Reproduction steps or PoC
- Suggested mitigation (if available)

## Deployment Safety Requirements

- Require at least one external review prior to production deployment.
- Deploy to a staging fork and replay expected governance actions.
- Verify source on chain and compare constructor arguments with reviewed values.
- Follow `docs/OPERATIONS.md` for cross-proposal hash collision handling and council rotation.
- Validate guarantees in `docs/SECURITY_PROPERTIES.md` against the release candidate bytecode.
