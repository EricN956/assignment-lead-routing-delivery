# Lead Routing Delivery

This Rails application implements the requested lead routing workflow from inbound lead intake through validation, DNC suppression, qualification, recipient routing, dispatch, and postback-based conversion tracking.

I treated the workflow as a small CRM pipeline rather than only a background script. The application keeps a clear lead lifecycle, stores each important decision as an audit event, and exposes the result through ActiveAdmin so the reviewer can inspect what happened to each lead.

---

## Implementation Summary

The application supports the full lead flow:

```text
Inbound JSON
  → validation and normalization
  → DNC suppression
  → qualification
  → recipient routing
  → recipient API delivery
  → postback verification
  → conversion tracking
```

The main implementation points are:

* Leads are imported from `data/inbound_leads.json`
* Invalid leads are stored with structured validation errors
* Duplicate inbound leads are skipped by `source_claim_id`
* DNC suppression is handled through the mock recipient service
* Qualification rules are applied from the lead prequalification fields
* Recipients are configured in the database instead of hard-coded in the routing processor
* Qualified leads are routed by state, active status, priority, and daily cap
* Apex, Beacon, and Citadel each have their own recipient client
* Dispatch attempts store redacted request and response details
* Retryable delivery failures are tracked with retry scheduling
* Postbacks require signature verification
* Conversions are recorded idempotently
* ActiveAdmin provides dashboard, lead list, and lead detail views

---

## Tech Stack

* Ruby 3.2.3
* Rails 8.1.3
* PostgreSQL
* ActiveAdmin
* Devise
* RSpec
* WebMock
* Net::HTTP

---

## Core Models

```text
Lead
LeadStageEvent
Recipient
LeadDelivery
DispatchAttempt
Conversion
```

`LeadStageEvent` is used as the lead audit trail. It records lifecycle events such as validation results, duplicate import handling, DNC decisions, qualification outcomes, routing decisions, dispatch results, postbacks, and conversions.

This makes each lead reviewable from the CRM UI without needing to rely only on logs or console output.

---

## Setup

Install dependencies:

```bash
bundle config set --local path "vendor/bundle"
bundle install
```

Create and seed the database:

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

The seed data creates the default admin account:

```text
admin@example.com
password
```

It also creates the default recipients:

```text
apex
beacon
citadel
```

---

## Running Tests

Run the full test suite:

```bash
bundle exec rspec
```

The suite covers the main workflow areas:

```text
lead ingestion
validation
duplicate import handling
DNC suppression
qualification rules
recipient routing
recipient API clients
dispatch attempts
retry handling
postback signature verification
conversion idempotency
ActiveAdmin CRM screens
```

---

## Running Locally

Start the Rails app:

```bash
bin/rails server
```

Open ActiveAdmin:

```text
http://localhost:3000/admin
```

Start the mock recipient server in another terminal:

```bash
CALLBACK_URL=http://localhost:3000/postbacks/recipients ruby mock_recipients/server.rb
```

The mock server exposes:

```text
GET  /health
POST /scrub/dnc
POST /apex/v2/leads
POST /beacon/api/addLead
POST /citadel/intake
```

---

## Lead Processing Commands

Import inbound leads:

```bash
bin/rails leads:ingest FILE=data/inbound_leads.json
```

Expected result for the provided sample file:

```text
total=25
created=24
valid=20
invalid=4
duplicates=1
failed=0
```

Run DNC suppression:

```bash
bin/rails leads:scrub_dnc
```

Run qualification:

```bash
bin/rails leads:qualify
```

Route qualified leads:

```bash
bin/rails leads:route
```

Dispatch routed deliveries:

```bash
bin/rails leads:dispatch
```

---

## Validation and Duplicate Handling

Inbound payloads are normalized before validation. The importer handles contact fields, state values, dates, test lead flags, prequalification data, and raw payload preservation.

Invalid leads are still saved, but they move to the `invalid` stage with structured `validation_errors`.

Duplicate inbound records are detected by `source_claim_id`. The application does not create a second lead, but it records a `duplicate_import_skipped` event in the existing lead timeline.

---

## DNC and Qualification

DNC checks are handled before qualification. Leads blocked by DNC move to `suppressed`; clear leads move to `scrubbed`.

Qualification evaluates these prequalification rules:

```text
has_injuries
not_at_fault
within_1_year
has_no_attorney
not_previously_dropped_or_settled
has_received_medical_treatment
```

Passing leads move to `qualified`. Failing leads move to `disqualified` with stored rule failure details. Test leads move to the `test` stage and are not routed.

---

## Routing

Routing is driven by seeded `Recipient` records. The routing processor evaluates:

```text
active recipient status
accepted accident states
daily cap
recipient priority
```

A qualified lead with eligible recipients gets one `LeadDelivery` record per recipient and moves to `routed`.

If no recipient can accept the lead, the lead moves to `unroutable`.

---

## Recipient Delivery

Each recipient integration is isolated in its own client class:

```text
Recipients::ApexClient
Recipients::BeaconClient
Recipients::CitadelClient
```

The dispatch layer uses a shared delivery result contract, so it does not need recipient-specific branching.

### Apex

```text
POST /apex/v2/leads
JSON payload
X-Api-Key authentication
```

### Beacon

```text
POST /beacon/api/addLead
Form-encoded payload
API key submitted in the form body
```

Beacon returns HTTP 200 for both success and rejection, so the Beacon client checks the response body to determine the actual delivery result.

### Citadel

```text
POST /citadel/intake
JSON payload
Bearer token authentication
```

Citadel duplicate and rate-limit responses are handled separately.

---

## Dispatch Attempts and Retries

Every outbound delivery attempt creates a `DispatchAttempt`.

The stored audit data includes:

```text
recipient
attempt number
request method
request URL
redacted request headers
redacted request body
response status
response body
retryable flag
error class
error message
```

Sensitive values such as API keys, bearer tokens, passwords, and signatures are redacted before being stored.

Retryable failures move the delivery to `retrying`, set `next_retry_at`, and enqueue another dispatch job until the configured maximum attempt count is reached.

---

## Postbacks and Conversions

The postback endpoint is:

```text
POST /postbacks/recipients
```

Required fields:

```text
recipient
source_claim_id
external_id
disposition
occurred_at
signature
```

Supported dispositions:

```text
signed
rejected
not_qualified
```

Postback signatures are verified with:

```ruby
Digest::SHA256.hexdigest("#{source_claim_id}:#{disposition}:#{POSTBACK_SHARED_SECRET}")
```

Valid postbacks create `Conversion` records. Repeated identical postbacks are idempotent and do not create duplicate conversions.

Invalid signatures return `401 unauthorized`.

Unknown leads with valid signatures are accepted and ignored safely.

---

## Admin Review

ActiveAdmin is available at:

```text
/admin
/admin/leads
/admin/leads/:id
```

The dashboard includes:

```text
Lead Lifecycle Summary
Delivery Status Summary
Recent Failed Dispatch Attempts
Recent Conversions and Postbacks
Recent Leads
```

The lead detail page includes:

```text
Lead Summary
Contact and Incident
Validation and Qualification
Recipient Deliveries
Dispatch Attempts
Conversions and Postbacks
Lifecycle Timeline
Raw Payload
```

These screens are included so a reviewer can inspect the result of the workflow directly through the UI.

---

## Configuration

Runtime configuration is centralized in:

```text
config/assessment.yml
```

Local example values are provided in:

```text
.env.example
```

Important configuration values include:

```text
MOCK_RECIPIENTS_BASE_URL
RECIPIENT_CALLBACK_URL
APEX_API_KEY
BEACON_API_KEY
CITADEL_BEARER_TOKEN
POSTBACK_SHARED_SECRET
DISPATCH_MAX_ATTEMPTS
```

---

## Reference

The original assignment materials are preserved at:

```text
docs/reference/ASSIGNMENT_README.md
```
