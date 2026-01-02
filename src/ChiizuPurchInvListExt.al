
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

                    PaymentService.PayInvoices(SelectedInvoiceNos);
                    Message('Selected invoice(s) were successfully paid via Chiizu.');
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

    trigger OnAfterGetRecord()
    var
        ChiizuInvoiceStatus: Record "Chiizu Invoice Status";
        PurchInvHeader: Record "Purch. Inv. Header";
    begin
        ChiizuStatus := ChiizuStatus::Open;

        // Default BC paid detection
        PurchInvHeader.Get(Rec."No.");
        PurchInvHeader.CalcFields("Remaining Amount");

        if PurchInvHeader."Remaining Amount" = 0 then begin
            ChiizuStatus := ChiizuStatus::Paid;
            exit;
        end;

        // Chiizu override
        if ChiizuInvoiceStatus.Get(Rec."No.") then
            ChiizuStatus := ChiizuInvoiceStatus.Status;
    end;
}
