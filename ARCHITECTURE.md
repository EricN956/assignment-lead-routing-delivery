# Architecture Notes

This implementation is organized around the lead lifecycle. I treated the assignment as a CRM workflow problem rather than a single import script, because the important part is not only moving data from one place to another, but being able to understand what happened to each lead at every step.

The main design goal was to make the system:

* easy to follow
* easy to test
* easy to extend
* safe around duplicate data
* transparent for CRM operators

The result is a Rails application with a clear pipeline, database-backed recipient configuration, recipient-specific API clients, idempotent postback handling, and an ActiveAdmin interface for reviewing the full lead history.

---

## Overall Flow

The application follows this flow:

```text
Inbound JSON
  → normalize payload
  → validate lead
  → check DNC
  → qualify lead
  → route to recipients
  → dispatch to recipient APIs
  → receive postback
  → record conversion
```

Each stage updates the lead and records an audit event. That means a reviewer can open a lead and see not only the current status, but also why it reached that status.

---

## Main Architectural Boundaries

I separated the application into four main layers:

```text
Models
  Store CRM state and relationships

Services
  Execute workflow decisions

Recipient clients
  Handle third-party API contracts

Admin UI
  Expose lead status, audit history, deliveries, and conversions
```

This separation keeps the models from becoming too large and avoids putting workflow logic directly into controllers or rake tasks.

---

## Core Domain Model

The main models are:

```text
Lead
LeadStageEvent
Recipient
LeadDelivery
DispatchAttempt
Conversion
```

### Lead

`Lead` is the central CRM record. It stores the normalized lead data, raw payload, validation errors, qualification results, and current lifecycle stage.

The lead moves through stages such as:

```text
received
invalid
validated
suppressed
scrubbed
disqualified
qualified
test
unroutable
routed
dispatched
delivered
failed
converted
rejected
```

### LeadStageEvent

`LeadStageEvent` is the audit trail.

Every important system decision creates a timeline event, including:

```text
lead_received
ingest_validation_passed
ingest_validation_failed
duplicate_import_skipped
dnc_clear
dnc_blocked
qualification_passed
qualification_failed
routing_completed
dispatch_started
dispatch_delivery_succeeded
recipient_postback_received
conversion_recorded
duplicate_postback_ignored
```

I added this because a CRM system should be explainable. If a lead is invalid, suppressed, disqualified, unroutable, failed, or converted, the application should show why.

### Recipient

`Recipient` stores downstream routing configuration.

A recipient includes:

```text
code
name
accepted states
priority
daily cap
active flag
endpoint path
authentication type
client class
settings
```

This keeps routing data-driven. Adding or changing recipients does not require changing the core routing processor.

### LeadDelivery

`LeadDelivery` represents one planned or attempted delivery from one lead to one recipient.

A lead can have multiple deliveries if multiple recipients are eligible.

### DispatchAttempt

`DispatchAttempt` stores the outbound API attempt.

It records:

```text
request method
request URL
redacted request headers
redacted request body
response status
response body
error details
retryable flag
```

This gives visibility into third-party delivery behavior without exposing sensitive credentials.

### Conversion

`Conversion` records recipient postback outcomes.

Conversions are idempotent so repeated identical postbacks do not create duplicate records.

---

## Ingestion and Validation

Inbound data is imported from the provided JSON file.

The ingestion flow is handled by:

```text
Leads::JsonImporter
Leads::PayloadNormalizer
Leads::PayloadValidator
```

The importer normalizes and validates each payload, then saves the result as a `Lead`.

Valid leads move to:

```text
validated
```

Invalid leads move to:

```text
invalid
```

Invalid leads are still stored because they are part of the CRM intake history. Their validation errors are saved as structured JSON, so an operator can see exactly which fields failed.

Duplicate inbound records are detected by:

```text
source_claim_id
```

The system does not create a second lead. Instead, it records a `duplicate_import_skipped` event on the existing lead.

---

## DNC and Qualification

After validation, the workflow applies DNC suppression before qualification.

DNC is handled by:

```text
Dnc::SuppressionClient
Leads::DncScrubber
```

Possible outcomes:

```text
blocked=true  → suppressed
blocked=false → scrubbed
```

Qualification is handled by:

```text
Leads::Qualification::Evaluator
Leads::QualificationProcessor
```

The qualification rules check the prequalification fields:

```text
has_injuries
not_at_fault
within_1_year
has_no_attorney
not_previously_dropped_or_settled
has_received_medical_treatment
```

Passing leads move to:

```text
qualified
```

Failing leads move to:

```text
disqualified
```

The failed rules are stored on the lead, so the reason is visible in the admin UI.

Test leads move to:

```text
test
```

and are not routed.

---

## Routing

Routing is handled by:

```text
Leads::Routing::RecipientSelector
Leads::RoutingProcessor
```

The selector evaluates recipients based on:

```text
active status
accepted accident state
daily cap
priority
```

If one or more recipients are eligible, the application creates one `LeadDelivery` per recipient and moves the lead to:

```text
routed
```

If no recipient can accept the lead, it moves to:

```text
unroutable
```

I kept routing separate from dispatch. Routing decides where a lead should go; dispatch decides how to send it.

---

## Recipient Integrations

The recipient integrations are intentionally separated into individual client classes:

```text
Recipients::ApexClient
Recipients::BeaconClient
Recipients::CitadelClient
```

Each client handles the exact request and response contract for that recipient.

All clients return a shared result object:

```text
Recipients::DeliveryResult
```

This lets the dispatch layer treat all recipients consistently, even though each recipient has a different API shape.

### Apex

Apex uses a JSON payload and API key header.

```text
POST /apex/v2/leads
X-Api-Key authentication
```

### Beacon

Beacon uses a form-encoded payload.

```text
POST /beacon/api/addLead
API key in form body
```

Beacon is different because it can return HTTP `200` for both success and failure, so the client checks the response body to determine the delivery result.

### Citadel

Citadel uses a JSON payload and bearer token.

```text
POST /citadel/intake
Bearer token authentication
```

Citadel duplicate and rate-limit responses are handled separately.

---

## Dispatch and Retry Handling

Dispatch is handled by:

```text
DispatchLeadDeliveryJob
Leads::Dispatch::DeliveryExecutor
Recipients::ClientRegistry
```

The dispatch executor:

1. loads the recipient client
2. sends the lead through that client
3. records a `DispatchAttempt`
4. updates the `LeadDelivery`
5. schedules retry when appropriate
6. updates the lead stage when delivery succeeds or all deliveries fail

Retryable failures move the delivery to:

```text
retrying
```

and set:

```text
next_retry_at
```

Permanent failures move the delivery to:

```text
failed
```

If at least one delivery succeeds, the lead can move to:

```text
delivered
```

If all deliveries fail, the lead moves to:

```text
failed
```

---

## Postbacks and Conversion Tracking

Postbacks are received at:

```text
POST /postbacks/recipients
```

The postback flow is handled by:

```text
Postbacks::RecipientReceiver
Postbacks::SignatureVerifier
Postbacks::ConversionRecorder
```

The receiver validates required fields, verifies the signature, finds the related lead and recipient, then records the conversion.

The signature is based on:

```ruby
Digest::SHA256.hexdigest("#{source_claim_id}:#{disposition}:#{POSTBACK_SHARED_SECRET}")
```

Supported dispositions are:

```text
signed
rejected
not_qualified
```

A signed postback moves the lead to:

```text
converted
```

Rejected or not-qualified postbacks can move the lead to:

```text
rejected
```

but an already converted lead is not downgraded later.

Repeated identical postbacks are idempotent. They do not create duplicate conversions, but they still create an audit event showing that a duplicate postback was received.

Unknown leads with valid signatures are accepted and ignored safely. This prevents the mock callback flow from failing because of ordering or external timing issues.

---

## Admin Review Layer

ActiveAdmin is used as the CRM review layer.

The dashboard gives a quick operational view:

```text
Lead Lifecycle Summary
Delivery Status Summary
Recent Failed Dispatch Attempts
Recent Conversions and Postbacks
Recent Leads
```

The lead detail page shows the full record:

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

This is included so the reviewer can inspect the workflow through the UI and see the full path of a lead from intake to final outcome.

---

## Why the Code Is Structured This Way

I avoided putting the workflow into one large service or rake task because that would make the solution harder to test and harder to extend.

Instead, each step has a clear responsibility:

```text
Importer        → creates leads from inbound data
Validator       → validates normalized attributes
DNC scrubber    → handles suppression
Evaluator       → applies qualification rules
Router          → selects recipients
Client classes  → handle recipient API contracts
Executor        → dispatches deliveries and records attempts
Receiver        → handles postbacks
Recorder        → records conversions idempotently
```

This structure makes it easier to add:

```text
new qualification rules
new recipients
new delivery statuses
new postback dispositions
new admin views
```

without rewriting the existing workflow.

---

## Reliability and Safety Decisions

The implementation includes several safeguards:

```text
duplicate import detection
duplicate postback prevention
structured validation errors
retryable delivery states
max retry attempts
redacted sensitive values
signed postback verification
audit events for workflow decisions
```

These choices were made to keep the workflow predictable and reviewable, which is especially important in CRM-style lead processing.

---

## Testing Coverage

The test suite covers both isolated behavior and full workflow behavior.

Coverage includes:

```text
lead ingestion and validation
duplicate import handling
DNC suppression
qualification rules
recipient routing
recipient client behavior
dispatch execution
retry handling
postback signature verification
conversion idempotency
ActiveAdmin dashboard and lead review pages
```

There are also higher-level flow specs for:

```text
ingestion and validation
DNC + qualification + routing
recipient dispatch through real clients
postback idempotency
```

These tests are intended to show that the system works as a complete workflow, not only as isolated classes.
