# Security Policy

## Supported Scope

This repository owns reusable SEOlith CI/CD and developer-environment standards. Changes here can affect many downstream repositories, so workflow behavior, action versions, security scans, and runner permissions are treated as security-sensitive.

## Required Controls

- Reusable workflows must use least-privilege permissions by default.
- Third-party actions must be reviewed before adoption and kept current.
- Workflow changes that affect build, test, security scan, packaging, or deployment behavior require owner review.
- Never commit real `.env` files, private keys, API tokens, cloud credentials, package feed credentials, or generated build output.
- Downstream-breaking workflow changes need migration notes in the pull request.

## Release Checklist

- Reusable workflows parse cleanly.
- Downstream smoke verification is run from at least one consuming repo when behavior changes.
- Security scan behavior is preserved or intentionally tightened.
- Action runtime/deprecation warnings are resolved or tracked.
