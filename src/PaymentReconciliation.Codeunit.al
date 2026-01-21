/*
🧪 HOW BC KNOWS IT’S A JOB:
---------------------------
1. Open Job Queue Entries
2. New
3. Object Type → Codeunit
4. Object ID → 50108
5. Set recurrence
6. Enable

➡️ That’s it.
BC treats it as a job automatically.
*/

codeunit 50108 "Payment Reconciliation"
{
    trigger OnRun()
    var
        InvoiceStatus: Record "Chiizu Invoice Status";
        VLE: Record "Vendor Ledger Entry";
        NewStatus: Enum "Chiizu Payment Status";
        StatusCalculator: Codeunit "Invoice Status Calculator";
    begin
        InvoiceStatus.Reset();

        if InvoiceStatus.FindSet() then
            repeat
                VLE.Reset();
                VLE.SetRange("Document Type", VLE."Document Type"::Invoice);
                VLE.SetRange("Document No.", InvoiceStatus."Invoice No.");

                if not VLE.FindFirst() then
                    continue;

                NewStatus := StatusCalculator.ResolveFromBC(VLE);

                if InvoiceStatus.Status <> NewStatus
                then
                    InvoiceStatus.SetStatusSystem(NewStatus, InvoiceStatus."Scheduled Date");
            until InvoiceStatus.Next() = 0;
    end;
}
