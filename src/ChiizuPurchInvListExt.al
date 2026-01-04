pageextension 50101 "Chiizu Posted Purch Inv Ext" extends "Posted Purchase Invoices"
{
    Caption = 'Chiizu | Posted Purchase Invoices';

    layout
    {
        addafter("Amount Including VAT")
        {
            field(ChiizuStatus; ChiizuStatus)
            {
                ApplicationArea = All;
                Caption = 'Status';
                ToolTip = 'Shows the Chiizu payment status for this posted purchase invoice.';
            }

            field(ChiizuScheduledDate; ChiizuScheduledDate)
            {
                ApplicationArea = All;
                Caption = 'Scheduled Date';
                ToolTip = 'If this invoice is scheduled for payment via Chiizu, this shows the scheduled payment date.';
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            // --------------------------
            // Pay Now (Bulk single API call)
            // --------------------------
            action(PayWithChiizu)
            {
                Caption = 'Pay with Chiizu';
                Image = Payment;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Send the selected posted purchase invoices to Chiizu for immediate payment.';

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                    PurchHeader: Record "Purch. Inv. Header";
                    SelectedInvoiceNos: List of [Code[20]];
                begin
                    CurrPage.SetSelectionFilter(PurchHeader);

                    if PurchHeader.IsEmpty() then
                        Error('Please select at least one invoice.');

                    if PurchHeader.FindSet() then
                        repeat
                            SelectedInvoiceNos.Add(PurchHeader."No.");
                        until PurchHeader.Next() = 0;

                    // Execute and report count
                    PaymentService.PayInvoices(SelectedInvoiceNos);
                    Message('%1 invoice(s) were successfully paid via Chiizu.', SelectedInvoiceNos.Count());
                end;
            }

            // --------------------------
            // Schedule Payment (Bulk single API call)
            // --------------------------
            action(ScheduleChiizuPayment)
            {
                Caption = 'Schedule Payment';
                Image = Calendar;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Schedule payment for the selected posted purchase invoices via Chiizu.';

                trigger OnAction()
                var
                    PurchHeader: Record "Purch. Inv. Header";
                    SelectedInvoiceNos: List of [Code[20]];
                    SchedulePage: Page "Chiizu Schedule Payment";
                begin
                    CurrPage.SetSelectionFilter(PurchHeader);

                    if PurchHeader.IsEmpty() then
                        Error('Please select at least one invoice to schedule.');

                    if PurchHeader.FindSet() then
                        repeat
                            SelectedInvoiceNos.Add(PurchHeader."No.");
                        until PurchHeader.Next() = 0;

                    SchedulePage.SetSelectedInvoices(SelectedInvoiceNos);
                    SchedulePage.RunModal();
                end;
            }
        }
    }

    var
        ChiizuStatus: Enum "Chiizu Payment Status";
        ChiizuScheduledDate: Date;

    trigger OnAfterGetRecord()
    var
        ChiizuInvoiceStatus: Record "Chiizu Invoice Status";
    begin
        // Default values
        ChiizuStatus := ChiizuStatus::Open;
        ChiizuScheduledDate := 0D;

        // BC paid detection (Remaining Amount = 0 => Paid)
        Rec.CalcFields("Remaining Amount");
        if Rec."Remaining Amount" = 0 then begin
            ChiizuStatus := ChiizuStatus::Paid;
            exit; // BC paid wins; Scheduled Date is irrelevant once fully paid
        end;

        // Chiizu override (status + scheduled date if present)
        if ChiizuInvoiceStatus.Get(Rec."No.") then begin
            ChiizuStatus := ChiizuInvoiceStatus.Status;

            // Assuming your status table contains the scheduled date column
            // Replace "Scheduled Date" with your actual field name if different
            ChiizuScheduledDate := ChiizuInvoiceStatus."Scheduled Date";
        end;
    end;
}
