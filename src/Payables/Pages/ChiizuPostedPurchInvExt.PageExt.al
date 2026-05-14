namespace Chiizu;

using Chiizu.Finalize;
using Microsoft.Purchases.History;

pageextension 1000001 "Chiizu Posted Purch Inv Ext" extends "Posted Purchase Invoices"
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
                PromotedOnly = true;
                ToolTip = 'Initiate immediate payment for the selected invoices via Chiizu.';

                trigger OnAction()
                var
                    PurchHeader: Record "Purch. Inv. Header";
                    PaymentService: Codeunit "Chiizu Payment Service";
                    FinalizePage: Page "Chiizu Finalize Payment";
                    SelectedInvoiceNos: List of [Code[20]];
                begin
                    CurrPage.SetSelectionFilter(PurchHeader);

                    if PurchHeader.IsEmpty() then
                        Error('Please select at least one invoice.');

                    if PurchHeader.FindSet() then
                        repeat
                            SelectedInvoiceNos.Add(PurchHeader."No.");
                        until PurchHeader.Next() = 0;

                    // ✅ EARLY VALIDATION
                    PaymentService.ValidateInvoicesForPayment(SelectedInvoiceNos);

                    // 2️⃣ Final review
                    FinalizePage.SetContext(SelectedInvoiceNos, Enum::"Chiizu Finalize Mode"::Pay);
                    FinalizePage.RunModal();
                end;
            }

            // --------------------------
            // Schedule Payment (Bulk)
            // --------------------------
            action(ChiizuScheduleChiizuPayment)
            {
                Caption = 'Schedule Payment';
                Image = Calendar;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Schedule payment for the selected posted purchase invoices via Chiizu.';

                trigger OnAction()
                var
                    PurchHeader: Record "Purch. Inv. Header";
                    InvoiceStatus: Record "Chiizu Invoice Status";
                    PaymentService: Codeunit "Chiizu Payment Service";
                    FinalizePage: Page "Chiizu Finalize Payment";
                    Status: Enum "Chiizu Payment Status";
                    SelectedInvoiceNos: List of [Code[20]];
                begin
                    CurrPage.SetSelectionFilter(PurchHeader);

                    if PurchHeader.IsEmpty() then
                        Error('Please select at least one invoice to schedule.');

                    if PurchHeader.FindSet() then
                        repeat
                            // 🔹 Default when no Chiizu record exists
                            Status := Status::Open;

                            if InvoiceStatus.Get(PurchHeader."No.") then
                                Status := InvoiceStatus.Status;

                            // 🔴 VALIDATION USING ENUM
                            if not (Status in [Status::Open, Status::"Partially Paid", Status::Failed]) then
                                Error(
                                    'Invoice %1 cannot be scheduled because its status is %2. ' +
                                    'Only Open, Partially Paid, or Failed invoices can be scheduled.',
                                    PurchHeader."No.",
                                    Status
                                );

                            SelectedInvoiceNos.Add(PurchHeader."No.");
                        until PurchHeader.Next() = 0;

                    // ✅ EARLY VALIDATION
                    PaymentService.ValidateInvoicesForPayment(SelectedInvoiceNos);

                    FinalizePage.SetContext(SelectedInvoiceNos, Enum::"Chiizu Finalize Mode"::Schedule);
                    FinalizePage.RunModal();
                end;
            }


            // --------------------------
            // CANCEL SCHEDULED PAYMENT (BULK SAFE)
            // --------------------------
            action(ChiizuCancelSchedule)
            {
                Caption = 'Cancel Scheduled Payment';
                Image = Cancel;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Enabled = IsSingleScheduledSelected;
                ToolTip = 'Cancel the scheduled payment for the selected invoice.';

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                begin
                    // Since it's only enabled when 1 is selected, we can skip the manual Count checks
                    if not Confirm('Are you sure you want to cancel the scheduled payment for Invoice %1?', false, Rec."No.") then
                        exit;

                    PaymentService.CancelScheduledInvoice(Rec."No.");

                    // Refresh to show the status change back to 'Open'
                    CurrPage.Update(false);
                end;
            }
        }
    }

    // ==========================
    // VARIABLES
    // ==========================
    var
        ChiizuStatus: Enum "Chiizu Payment Status";
        ChiizuScheduledDate: Date;
        IsSingleScheduledSelected: Boolean;

    // ==========================
    // PER-ROW DISPLAY LOGIC
    // ==========================
    trigger OnAfterGetRecord()
    var
        ChiizuInvoiceStatus: Record "Chiizu Invoice Status";
    begin
        ChiizuStatus := ChiizuStatus::Open;
        ChiizuScheduledDate := 0D;

        // BC paid wins
        Rec.CalcFields("Remaining Amount");
        if Rec."Remaining Amount" = 0 then begin
            ChiizuStatus := ChiizuStatus::Paid;
            exit;
        end;

        // Chiizu status + scheduled date
        if ChiizuInvoiceStatus.Get(Rec."No.") then begin
            ChiizuStatus := ChiizuInvoiceStatus.Status;
            ChiizuScheduledDate := ChiizuInvoiceStatus."Scheduled Date";
        end;
    end;

    // ==========================
    // SELECTION-BASED ENABLEMENT
    // ==========================
    trigger OnAfterGetCurrRecord()
    begin
        UpdateSelectionState();
    end;

    local procedure UpdateSelectionState()
    var
        SelInv: Record "Purch. Inv. Header";
        Stat: Record "Chiizu Invoice Status";
    begin
        IsSingleScheduledSelected := false;

        CurrPage.SetSelectionFilter(SelInv);

        // Magic: Check if exactly 1 record is in the selection
        if SelInv.Count() = 1 then
            if SelInv.FindFirst() then
                // Check if that specific record is 'Scheduled'
                if Stat.Get(SelInv."No.") then
                    IsSingleScheduledSelected := (Stat.Status = Stat.Status::Scheduled);
    end;
}
