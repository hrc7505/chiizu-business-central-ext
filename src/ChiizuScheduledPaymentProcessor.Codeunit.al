
codeunit 50105 "Scheduled Payment Processor"
{
    SingleInstance = false;

    trigger OnRun()
    var
        ScheduledPayment: Record "Chiizu Scheduled Payment";
        PaymentService: Codeunit "Chiizu Payment Service";
        DueInvoiceNos: List of [Code[20]];
    begin
        // Collect all schedules due today or earlier
        ScheduledPayment.Reset();
        ScheduledPayment.SetRange(Status, ScheduledPayment.Status::Scheduled);
        ScheduledPayment.SetFilter("Scheduled Date", '<=%1', Today);

        if ScheduledPayment.FindSet() then
            repeat
                DueInvoiceNos.Add(ScheduledPayment."Invoice No.");
            until ScheduledPayment.Next() = 0;

        if DueInvoiceNos.Count() = 0 then
            exit; // nothing to do

        // Call payment in bulk (single API call)
        PaymentService.PayInvoices(DueInvoiceNos);

        // On success, remove the processed schedules so they won't re-run
        ScheduledPayment.Reset();
        ScheduledPayment.SetRange(Status, ScheduledPayment.Status::Scheduled);
        ScheduledPayment.SetFilter("Scheduled Date", '<=%1', Today);

        if ScheduledPayment.FindSet(true) then
            repeat
                ScheduledPayment.Delete(true);
            until ScheduledPayment.Next() = 0;
    end;
}
