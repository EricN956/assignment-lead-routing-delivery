# Lead Routing Delivery

This Rails application implements the lead routing workflow as a small CRM-style system. A lead can be followed from initial intake through validation, DNC suppression, qualification, recipient routing, delivery attempts, postback handling, and final conversion tracking.

The implementation focuses on making the workflow easy to inspect and reason about. Each important decision creates an audit event, recipient configuration is stored in the database instead of being hard-coded, and delivery/postback behavior is handled idempotently to avoid duplicate records.

---

## What the Application Does

The application supports the full lead lifecycle:

```text
Inbound lead data
  → validation
  → DNC suppression
  → qualification
  → routing
  → recipient delivery
  → postback handling
  → conversion tracking
```

Implemented functionality includes:

* Importing leads from `data/inbound_leads.json`
* Normalizing phone numbers, emails, dates, state values, and raw payloads
* Marking invalid leads with structured validation errors
* Skipping duplicate leads by `source_claim_id`
* Running DNC checks against the mock service
* Applying qualification rules from prequalification data
* Routing qualified leads to Apex, Beacon, and Citadel based on state, active status, priority, and daily cap
* Sending recipient API requests through dedicated client classes
* Recording dispatch attempts with redacted request/response audit data
* Handling retryable and permanent delivery failures
* Receiving signed recipient postbacks
* Recording conversions idempotently
* Providing an ActiveAdmin CRM interface for review and troubleshooting

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
* Tailwind CSS / cssbundling-rails

---

## Main Models

```text
Lead
LeadStageEvent
Recipient
LeadDelivery
DispatchAttempt
Conversion
```

`LeadStageEvent` is the main audit trail. It records what happened to a lead, when it happened, and why. This makes each lead reviewable without needing to inspect logs or run console commands.

---

## Setup

Install Ruby dependencies:

```bash
bundle config set --local path "vendor/bundle"
bundle install
```

Install JavaScript/CSS build dependencies:

```bash
npm install
```

Build CSS assets:

```bash
npm run build:css
```

Set up the database:

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

The seed data creates:

```text
Admin user:
admin@example.com
password

Recipients:
apex
beacon
citadel
```

---

## Running the Test Suite

Run the full test suite:

```bash
bundle exec rspec
```

The test suite covers the main workflow, including ingestion, validation, duplicate handling, DNC checks, qualification, routing, recipient clients, dispatch execution, postback signature verification, idempotent conversions, and the ActiveAdmin CRM screens.

---

## Running the App

Start Rails:

```bash
bin/rails server
```

Open ActiveAdmin:

```text
http://localhost:3000/admin
```

---

## Mock Recipient Server

Start the mock recipient server in a second terminal:

```bash
CALLBACK_URL=http://localhost:3000/postbacks/recipients ruby mock_recipients/server.rb
```

The mock server provides:

```text
GET  /health
POST /scrub/dnc
POST /apex/v2/leads
POST /beacon/api/addLead
POST /citadel/intake
```

---

## Running the Workflow

Import the inbound leads:

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

## Recipient Integrations

The recipient integrations are separated into individual client classes so each downstream contract stays isolated.

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

Beacon returns HTTP 200 for both success and rejection, so the client reads the response body to determine the final delivery result.

### Citadel

```text
POST /citadel/intake
JSON payload
Bearer token authentication
```

Citadel handles duplicate and rate-limit responses separately.

---

## Postbacks

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

Signatures are verified using:

```ruby
Digest::SHA256.hexdigest("#{source_claim_id}:#{disposition}:#{POSTBACK_SHARED_SECRET}")
```

Postbacks are idempotent. If the same signed postback is received more than once, the application does not create duplicate conversion records, but it still records that the duplicate postback was received.

---

## Admin CRM

The ActiveAdmin interface is available at:

```text
/admin
/admin/leads
/admin/leads/:id
```

The dashboard shows a quick operational summary:

```text
Lead Lifecycle Summary
Delivery Status Summary
Recent Failed Dispatch Attempts
Recent Conversions and Postbacks
Recent Leads
```

The lead detail page shows:

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

These views make the lead lifecycle reviewable through the UI instead of relying only on tests or console output.

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

Important configurable values include:

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

## Design Choices

The routing logic is data-driven. Recipients are stored as database records, and the routing processor evaluates active status, accepted states, daily cap, and priority.

Recipient API logic is kept separate from the dispatch executor. The dispatch layer only understands a shared delivery result contract, while Apex, Beacon, and Citadel each handle their own request and response format.

The system is intentionally audit-first. Validation failures, duplicate imports, DNC decisions, qualification failures, routing decisions, dispatch attempts, and postbacks are all visible through the lead timeline.

Sensitive values such as API keys, bearer tokens, passwords, and signatures are filtered or redacted before being stored in audit data.

---

## Reference

The original assignment materials are preserved under:

```text
docs/reference/ASSIGNMENT_README.md
```
