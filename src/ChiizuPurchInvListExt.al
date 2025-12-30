
pageextension 50101 "Chiizu Posted Purch Inv Ext" extends "Posted Purchase Invoices"
{
    Caption = 'Chiizu | Posted Purchase Invoices';

    layout
    {
        addafter("Remaining Amount")
        {
            field("Chiizu Paid"; IsChiizuPaid())
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether this invoice was paid via Chiizu.';
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            // --------------------------
            // Pay Now (Bulk in a single API call)
            // --------------------------
            action(PayWithChiizu)
            {
                Caption = 'Pay with Chiizu';
                Image = Payment;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                    PurchHeader: Record "Purch. Inv. Header";
                    SelectedInvoiceNos: List of [Code[20]];
                begin
                    // Get the selection from the list page
                    CurrPage.SetSelectionFilter(PurchHeader);

                    if PurchHeader.IsEmpty() then
                        Error('Please select at least one invoice.');

                    // Collect selected invoice numbers
                    if PurchHeader.FindSet() then
                        repeat
                            SelectedInvoiceNos.Add(PurchHeader."No.");
                        until PurchHeader.Next() = 0;

                    // Single bulk call: validates all, builds payload, calls API once
                    PaymentService.PayInvoices(SelectedInvoiceNos);

                    Message('Selected invoice(s) were successfully paid via Chiizu.');
                end;
            }

            // --------------------------
            // Schedule Payment
            // --------------------------
            action(ScheduleChiizuPayment)
            {
                Caption = 'Schedule Payment';
                Image = Calendar;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    SchedulePage: Page "Chiizu Schedule Payment";
                    PurchHeader: Record "Purch. Inv. Header";
                begin
                    CurrPage.SetSelectionFilter(PurchHeader);

                    if PurchHeader.Count <> 1 then
                        Error('Please select exactly one invoice to schedule.');

                    // Use the selected record, not Rec
                    if PurchHeader.FindFirst() then begin
                        SchedulePage.SetPurchaseHeader(PurchHeader);
                        SchedulePage.RunModal();
                    end else
                        Error('Unable to resolve selected invoice.');
                end;
            }
        }
    }

    // -----------------------------
    // Helpers
    // -----------------------------
    local procedure IsChiizuPaid(): Boolean
    var
        Status: Record "Chiizu Invoice Status";
    begin
        if Status.Get(Rec."No.") then
            exit(Status."Paid via Chiizu");
        exit(false);
    end;
}
