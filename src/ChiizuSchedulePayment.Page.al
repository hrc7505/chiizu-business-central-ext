
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
            group(Instructions)
            {
                Caption = 'Instructions';
                field(InfoText; InfoText)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Review the invoices to be scheduled. Set a Scheduled Date for each line and choose Schedule All.';
                }
                field(DefaultScheduledDate; DefaultScheduledDate)
                {
                    ApplicationArea = All;
                    Caption = 'Default Scheduled Date';
                    ToolTip = 'Set a default scheduled date to apply to all lines.';
                }
            }

            repeater(Invoices)
            {
                ShowCaption = true;
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Remaining amount to be scheduled (document currency).';
                }
                field("Scheduled Date"; Rec."Scheduled Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date on which this invoice will be scheduled for payment.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ApplyDefaultDate)
            {
                Caption = 'Apply Default Date to All';
                Image = Calendar;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    Rec.Reset();
                    if Rec.FindSet() then
                        repeat
                            Rec."Scheduled Date" := DefaultScheduledDate;
                            Rec.Modify();
                        until Rec.Next() = 0;

                    CurrPage.Update(false);
                end;
            }

            action(ScheduleAll)
            {
                Caption = 'Schedule All';
                Image = Calendar;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    PaymentService: Codeunit "Chiizu Payment Service";
                    Cnt: Integer;
                begin
                    // Validate using the page dataset directly
                    Rec.Reset();
                    if Rec.IsEmpty() then
                        Error('No invoices to schedule.');

                    if Rec.FindSet() then
                        repeat
                            if Round(Abs(Rec.Amount), 0.01, '=') = 0 then
                                Error('Invoice %1 has no remaining payable amount.', Rec."Invoice No.");

                            if Rec."Scheduled Date" < Today then
                                Error('Scheduled date for invoice %1 must be today or later.', Rec."Invoice No.");
                        until Rec.Next() = 0;

                    // Single API call using the page's temporary dataset
                    Cnt := PaymentService.ScheduleInvoices(Rec);

                    Message('Successfully scheduled %1 invoice(s).', Cnt);
                    CurrPage.Close();
                end;
            }

            action(Cancel)
            {
                Caption = 'Cancel';
                Image = Cancel;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        InfoText: Text;
        DefaultScheduledDate: Date;
        NextEntryNo: Integer;

    trigger OnOpenPage()
    begin
        InfoText := 'Set Scheduled Date for each invoice (or apply a default date) and choose Schedule All.';
        if DefaultScheduledDate = 0D then
            DefaultScheduledDate := Today;

        NextEntryNo := 1; // temp PK counter
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
        BestRemaining: Decimal;
        FoundPayable: Boolean;
    begin
        Rec.Reset();
        Rec.DeleteAll();
        NextEntryNo := 1; // <<< reset temp PK counter each load

        ErrorText := '';
        HasErrors := false;

        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices were provided.');

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            // Try Open VLE with non-zero remaining
            VendLedgEntry.Reset();
            VendLedgEntry.SetRange("Document Type", VendLedgEntry."Document Type"::Invoice);
            VendLedgEntry.SetRange("Document No.", InvNo);
            VendLedgEntry.SetRange(Open, true);

            FoundPayable := false;
            BestRemaining := 0;

            if VendLedgEntry.FindSet() then
                repeat
                    VendLedgEntry.CalcFields("Remaining Amount");
                    if Round(Abs(VendLedgEntry."Remaining Amount"), 0.01, '=') > 0 then begin
                        FoundPayable := true;
                        PayableVLE := VendLedgEntry;
                        break;
                    end;
                until VendLedgEntry.Next() = 0;

            // Fallback: any VLE with non-zero remaining (choose max)
            if not FoundPayable then begin
                VendLedgEntry.Reset();
                VendLedgEntry.SetRange("Document Type", VendLedgEntry."Document Type"::Invoice);
                VendLedgEntry.SetRange("Document No.", InvNo);
                if VendLedgEntry.FindSet() then
                    repeat
                        VendLedgEntry.CalcFields("Remaining Amount");
                        if Round(Abs(VendLedgEntry."Remaining Amount"), 0.01, '=') > 0 then
                            if Abs(VendLedgEntry."Remaining Amount") > BestRemaining then begin
                                BestRemaining := Abs(VendLedgEntry."Remaining Amount");
                                PayableVLE := VendLedgEntry;
                                FoundPayable := true;
                            end;
                    until VendLedgEntry.Next() = 0;
            end;

            if not FoundPayable then begin
                ErrorText += StrSubstNo('• No payable vendor ledger entry found for invoice %1.\n', InvNo);
                HasErrors := true;
                continue;
            end;

            // Disallow scheduling if already paid via Chiizu
            if Status.Get(InvNo) then
                if Status."Paid via Chiizu" then begin
                    ErrorText += StrSubstNo('• Invoice %1 is already paid via Chiizu.\n', InvNo);
                    HasErrors := true;
                    continue;
                end;

            // Insert temporary worksheet line (assign Entry No. manually)
            Rec.Init();
            Rec."Entry No." := NextEntryNo;
            NextEntryNo += 1;

            Rec."Invoice No." := PayableVLE."Document No.";
            Rec."Vendor No." := PayableVLE."Vendor No.";
            PayableVLE.CalcFields("Remaining Amount");
            Rec.Amount := Abs(PayableVLE."Remaining Amount");
            Rec."Scheduled Date" := Today;
            Rec.Status := Rec.Status::Open;
            Rec.Insert();
        end;

        if Rec.IsEmpty() then
            Error('None of the selected invoices are eligible for scheduling.');

        if HasErrors and (ErrorText <> '') then
            Message(ErrorText);
    end;
}
