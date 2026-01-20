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
                    Message('%1 invoice(s) were successfully paid via Chiizu.', SelectedInvoiceNos.Count());
                end;
            }

            // --------------------------
            // Schedule Payment (Bulk)
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
                    InvoiceStatus: Record "Chiizu Invoice Status";
                    Status: Enum "Chiizu Payment Status";
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

                    SchedulePage.SetSelectedInvoices(SelectedInvoiceNos);
                    SchedulePage.RunModal();
                end;
            }


            // --------------------------
            // CANCEL SCHEDULED PAYMENT (BULK SAFE)
            // --------------------------
            action(CancelChiizuSchedule)
            {
                Caption = 'Cancel Scheduled Payment';
                Image = Cancel;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;

                Enabled = IsAnyScheduled;

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                    SelPurchInv: Record "Purch. Inv. Header";
                    SelectedInvoiceNos: List of [Code[20]];
                begin
                    CurrPage.SetSelectionFilter(SelPurchInv);

                    // 🔒 CRITICAL: only explicit user selection
                    SelPurchInv.MarkedOnly(true);

                    if SelPurchInv.IsEmpty() then
                        Error('No invoices selected.');

                    SelPurchInv.FindSet();
                    repeat
                        SelectedInvoiceNos.Add(SelPurchInv."No.");
                    until SelPurchInv.Next() = 0;

                    if not Confirm(
                        StrSubstNo(
                            'Cancel scheduled payment for %1 invoice(s)?\%2',
                            SelectedInvoiceNos.Count(),
                            FormatInvoiceList(SelectedInvoiceNos)
                        ),
                        false
                    ) then
                        exit;

                    PaymentService.CancelScheduledInvoices(SelectedInvoiceNos);

                    // 🔄 Hard refresh (selection naturally resets)
                    CurrPage.Update(true);
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
        IsAnyScheduled: Boolean;

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
        IsAnyScheduled := false;

        CurrPage.SetSelectionFilter(SelInv);
        if SelInv.FindSet() then
            repeat
                if Stat.Get(SelInv."No.") then
                    if Stat.Status = Stat.Status::Scheduled then begin
                        IsAnyScheduled := true;
                        exit;
                    end;
            until SelInv.Next() = 0;
    end;

    local procedure FormatInvoiceList(InvoiceNos: List of [Code[20]]): Text
    var
        i: Integer;
        Txt: Text;
    begin
        for i := 1 to InvoiceNos.Count() do
            Txt += '• ' + InvoiceNos.Get(i) + '\';

        exit(Txt);
    end;
}
