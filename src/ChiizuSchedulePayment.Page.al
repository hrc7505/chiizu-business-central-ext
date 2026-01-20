
page 50120 "Chiizu Schedule Payment"
{
    PageType = Worksheet;
    SourceTable = "Chiizu Scheduled Payment";
    SourceTableTemporary = true;
    Caption = 'Schedule Payment (Chiizu)';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Header)
            {
                Caption = '';
                field(DefaultScheduledDate; DefaultScheduledDate)
                {
                    ApplicationArea = All;
                    Caption = 'Scheduled Date for All';
                    ToolTip = 'This scheduled date will be applied to all invoices in the list.';

                    trigger OnValidate()
                    begin
                        ApplyScheduledDateToAllLines();
                    end;
                }
            }

            repeater(Invoices)
            {
                ShowCaption = true;

                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; Editable = false; Visible = false; }
                field("Invoice No."; Rec."Invoice No.") { ApplicationArea = All; Editable = false; ToolTip = 'The posted purchase invoice number.'; }
                field("Vendor No."; Rec."Vendor No.") { ApplicationArea = All; Editable = false; ToolTip = 'The vendor related to this invoice.'; }
                field(Amount; Rec.Amount) { ApplicationArea = All; Editable = false; ToolTip = 'Outstanding amount to be scheduled for payment.'; }
                field(Status; Rec.Status) { ApplicationArea = All; Editable = false; ToolTip = 'Chiizu payment status computed same as on Posted Purchase Invoices.'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ScheduleAll)
            {
                Caption = 'Schedule All';
                Image = Calendar;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Schedule all listed invoices for payment on the selected date.';

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                    Cnt: Integer;
                begin
                    if DefaultScheduledDate < Today then
                        Error('Scheduled date must be today or later.');

                    Rec.Reset();
                    if Rec.IsEmpty() then
                        Error('No invoices to schedule.');

                    // Ensure every line has the top date before scheduling
                    if Rec.FindSet() then
                        repeat
                            Rec."Scheduled Date" := DefaultScheduledDate;
                            Rec.Modify(true);
                        until Rec.Next() = 0;

                    // Optional: recompute statuses in case something changed, and block Paid
                    Rec.Reset();
                    if Rec.FindSet() then
                        repeat
                            Rec.Status := GetChiizuStatus(Rec."Invoice No.");
                            Rec.Modify(true);
                        until Rec.Next() = 0;

                    Rec.Reset();
                    Rec.SetRange(Status, Rec.Status::Paid);
                    if not Rec.IsEmpty() then
                        Error('One or more invoices are already paid and cannot be scheduled. Refresh statuses and adjust selection.');

                    // Proceed with scheduling
                    Cnt := PaymentService.ScheduleInvoices(Rec);
                    Message('Successfully scheduled %1 invoice(s).', Cnt);
                    CurrPage.Close();
                end;
            }

            action(RefreshStatuses)
            {
                Caption = 'Refresh Statuses';
                Image = Refresh;
                ApplicationArea = All;
                ToolTip = 'Recompute the Chiizu status for all listed invoices.';

                trigger OnAction()
                begin
                    Rec.Reset();
                    if Rec.FindSet() then
                        repeat
                            Rec.Status := GetChiizuStatus(Rec."Invoice No.");
                            Rec.Modify(true);
                        until Rec.Next() = 0;

                    CurrPage.Update(false);
                end;
            }

            action(Cancel)
            {
                Caption = 'Cancel';
                Image = Cancel;
                ApplicationArea = All;
                ToolTip = 'Close without scheduling.';
                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        DefaultScheduledDate: Date;
        NextEntryNo: Integer;

    // Initialize default date
    trigger OnOpenPage()
    begin
        if DefaultScheduledDate = 0D then
            DefaultScheduledDate := Today;

        NextEntryNo := 1;
    end;

    procedure SetSelectedInvoices(SelectedInvoiceNos: List of [Code[20]])
    var
        VendLedgEntry: Record "Vendor Ledger Entry";
        Status: Record "Chiizu Invoice Status";
        ErrorText: Text;
        HasErrors: Boolean;
        InvNo: Code[20];
        i: Integer;
        PayableVLE: Record "Vendor Ledger Entry";
        FoundPayable: Boolean;
    begin
        Rec.Reset();
        Rec.DeleteAll();
        NextEntryNo := 1;
        ErrorText := '';
        HasErrors := false;

        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices were provided.');

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            // Validate there's an open payable VLE with remaining amount > 0
            VendLedgEntry.Reset();
            VendLedgEntry.SetRange("Document Type", VendLedgEntry."Document Type"::Invoice);
            VendLedgEntry.SetRange("Document No.", InvNo);
            VendLedgEntry.SetRange(Open, true);

            FoundPayable := false;

            if VendLedgEntry.FindSet() then
                repeat
                    VendLedgEntry.CalcFields("Remaining Amount");
                    if Round(Abs(VendLedgEntry."Remaining Amount"), 0.01, '=') > 0 then begin
                        PayableVLE := VendLedgEntry;
                        FoundPayable := true;
                        break;
                    end;
                until VendLedgEntry.Next() = 0;

            if not FoundPayable then begin
                ErrorText += StrSubstNo('• No payable vendor ledger entry found for invoice %1.\n', InvNo);
                HasErrors := true;
                continue;
            end;

            // If Chiizu status record explicitly marks Paid, skip
            if Status.Get(InvNo) then
                if Status.Status = Status.Status::Paid then begin
                    ErrorText += StrSubstNo('• Invoice %1 is already paid.\n', InvNo);
                    HasErrors := true;
                    continue;
                end;

            // Create temp schedule row
            Rec.Init();
            Rec."Entry No." := NextEntryNo;
            NextEntryNo += 1;

            Rec."Invoice No." := PayableVLE."Document No.";
            Rec."Vendor No." := PayableVLE."Vendor No.";
            Rec.Amount := Abs(PayableVLE."Remaining Amount");

            // Compute the same status logic as on the Posted Purchase Invoices page
            Rec.Status := GetChiizuStatus(Rec."Invoice No.");

            // Use top Scheduled Date (can be edited via header field)
            Rec."Scheduled Date" := DefaultScheduledDate;

            Rec.Insert(true);
        end;

        if Rec.IsEmpty() then
            Error('None of the selected invoices are eligible for scheduling.');

        if HasErrors and (ErrorText <> '') then
            Message(ErrorText);

        // Refresh page to show inserted rows
        CurrPage.Update(false);
    end;

    local procedure ApplyScheduledDateToAllLines()
    begin
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                Rec."Scheduled Date" := DefaultScheduledDate;
                Rec.Modify(true);
            until Rec.Next() = 0;

        CurrPage.Update(false);
    end;

    local procedure GetChiizuStatus(InvNo: Code[20]): Enum "Chiizu Payment Status"
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        ChiizuInvoiceStatus: Record "Chiizu Invoice Status";
        StatusEnum: Enum "Chiizu Payment Status";
    begin
        // Default to Open
        StatusEnum := StatusEnum::Open;

        // BC paid detection (Remaining Amount = 0 => Paid)
        if PurchInvHeader.Get(InvNo) then begin
            PurchInvHeader.CalcFields("Remaining Amount");
            if PurchInvHeader."Remaining Amount" = 0 then
                exit(StatusEnum::Paid); // BC paid wins
        end;

        // Chiizu override (if present)
        if ChiizuInvoiceStatus.Get(InvNo) then
            exit(ChiizuInvoiceStatus.Status);

        exit(StatusEnum);
    end;
}
