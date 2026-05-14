# Chiizu Business Central Extension — Codebase Overview & Statement Import Issue Notes

## Summary
This repo is a Microsoft Dynamics 365 Business Central extension written in **AL** (“Chiizu”). It integrates with external services (e.g., bank funding accounts/transactions and payment scheduling) and persists results into BC business objects such as **Bank Acc. Reconciliation** and **Bank Acc. Reconciliation Line**. The file you highlighted (`src/BankFeeds/Codeunits/ChiizuStatementImport.Codeunit.al`) orchestrates an import “agent loop” that:
1) resolves/creates the appropriate reconciliation header,
2) calls an external API to fetch transaction pages using a delta date,
3) inserts reconciliation lines while preventing duplicates.

## Architecture
- **Pattern**: Orchestration codeunits that coordinate BC record updates plus external calls via a shared API client codeunit.
- **Major subsystems**:
  - `BankFeeds` — statement import + reconciliation line creation.
  - `Payables` — bulk payment scheduling/cancellation (also uses shared API client patterns).
  - `utils` — shared HTTP/JSON client and helpers (`Chiizu API Client`).
  - `Core/Setup` — connection/credential establishment (`Chiizu Setup Management`).
- **Execution start**:
  - Manual invocation uses `trigger OnRun()` and a `RecordRef` “unpacker” driven by `Rec."Related Record"`.
  - Background/job invocation uses `BackgroundSyncAccount(BankAccNo)` which ensures an open header exists and then runs the core import procedure.
- **Technology stack**: AL `codeunit`s; heavy usage of `Record`, `RecordRef`, `JsonObject/JsonArray`, and standard BC triggers/procedures.

## Key Abstractions (most relevant to `ChiizuStatementImport`)
### `codeunit 1000019 "Chiizu Statement Import"`
- **File**: `src/BankFeeds/Codeunits/ChiizuStatementImport.Codeunit.al`
- **Responsibility**: Imports external bank transactions into `"Bank Acc. Reconciliation Line"`.
- **Interface**:
  - `trigger OnRun()` — resolves reconciliation context based on `Rec."Related Record"` using `RecordRef`.
  - `procedure BackgroundSyncAccount(BankAccNo: Code[20])` — job/webhook entry point; creates an open `"Bank Acc. Reconciliation"` header when missing.
  - `local procedure ImportTransactionsToRecon(var BankAccRecon: Record "Bank Acc. Reconciliation")` — delta sync, paging, and line insertion.
- **Lifecycle**: Stateless per run; state is persisted into BC tables (header + lines).

### `codeunit "Chiizu API Client"` (used via variable `ApiClient`)
- **File**: `src/utils/ChiizuAPIClient.Codeunit.al` (not fully read here)
- **Responsibility**: Performs HTTP GET/POST and returns JSON objects, plus helpers such as `GetJsonString`, `GetJsonDate`, `GetJsonDecimal`.

## Data Flow (statement import)
1. **Invocation context**
   - `OnRun()` gets `Rec."Related Record"` via `RecordRef.Get(Rec."Related Record")`.
   - Switches by `RecRef.Number` (table id):
     - `"Bank Acc. Reconciliation"` → reads `"Bank Account No."` from that header.
     - `"Bank Account"` → picks the latest reconciliation header for that bank account.
     - `"Bank Acc. Reconciliation Line"` → derives bank account + statement type + statement no from the line, then finds the header.
2. **Header selection/creation**
   - Background path calls `BackgroundSyncAccount(BankAccNo)` which ensures an open header exists (creates if not).
3. **Delta sync window**
   - `ImportTransactionsToRecon` reads last `"Posting Date"` from `"Bank Account Ledger Entry"` for the bank account.
   - If no ledger history exists, it uses fallback `CalcDate('<-30D>', Today)`.
4. **Paging loop**
   - Calls API using a URL with:
     - `startDate=YYYY-MM-DD`
     - `page=<CurrentPage>`
   - Stops when:
     - the `transactions` property is missing, or
     - `transactions` array exists but `Count() = 0`.
5. **Per transaction insertion**
   - Extracts `TxnId` from JSON field `id`.
   - Uses duplicate check on a combination of:
     - Statement Type, Bank Account No, Statement No, Transaction ID
   - If not duplicate:
     - inserts new `"Bank Acc. Reconciliation Line"` with validated fields:
       - `"Transaction Date"` from JSON `date`
       - `"Statement Amount"` from JSON `amount`
       - `"Transaction ID"` and truncated description
     - increments `NextLineNo` by `+10000` per insert.
6. **Optional header auto-fill**
   - If `TotalImported > 0` and `"Statement Date" = 0D`, it sets header `"Statement Date"` from the newest line’s `"Transaction Date"`.

## Non-Obvious Behaviors & Design Decisions
- **RecordRef-driven “universal unpacker”**: `OnRun()` is designed to work off `Rec."Related Record"` and infer the import target from the selected record type. This is powerful but fragile if the UI “Related Record” semantics change.
- **Delta sync is ledger-based, not reconciliation-based**: it chooses `LastSyncDate` from `"Bank Account Ledger Entry"` posting dates, not from the last imported transaction date stored on the statement header/lines. Duplicate protection (by `"Transaction ID"`) is therefore essential.
- **Paging termination relies on JSON shape**: it breaks if `transactions` key is missing (not only when it’s empty), which is robust to some API pagination behaviors.

## About the specific “Line 3: using … referenced from repository” hint
From the file content you provided, the `using` directives are straightforward AL namespace imports, e.g.:
- `using Chiizu.Utils;`
- `using Microsoft.Bank.BankAccount;`
- `using Microsoft.Bank.Ledger;`
- `using Microsoft.Bank.Reconciliation;`
- `using System.IO;`

A linter/editor “hint” that points to another file path (like your referenced `ChiizuPaymentService.Codeunit.al`) is typically not evidence of a runtime bug in `ChiizuStatementImport.Codeunit.al`; it’s more consistent with:
- a tooling false positive about “unused using” or symbol resolution, or
- a stale reference/mapping created by the editor/analysis engine.

**Practical next steps for a developer** (no code changes required here):
- verify which AL symbols in `ChiizuStatementImport.Codeunit.al` actually require each `using` line (some may be unused),
- remove unused `using`s if the hint persists,
- otherwise treat it as a tooling/analysis mismatch rather than a compile failure in BC.

## Suggested Reading Order
1. `src/BankFeeds/Codeunits/ChiizuStatementImport.Codeunit.al`
2. `src/utils/ChiizuAPIClient.Codeunit.al`
3. `src/Payables/Codeunits/ChiizuPaymentService.Codeunit.al`
4. `src/Core/Setup/ChiizuSetupManagement.Codeunit.al`

## Action Checklist for the “line 3 using …” hint
- [ ] Confirm which symbols in `ChiizuStatementImport.Codeunit.al` actually require each `using` line.
- [ ] Remove unused `using` directives if safe/verified.
- [ ] If it still appears, re-check whether the hint is from stale tooling/symbol mapping rather than actual AL compilation.