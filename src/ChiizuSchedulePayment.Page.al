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
                    ToolTip = 'This scheduled date will be applied to all invoices.';

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
                field("Invoice No."; Rec."Invoice No.") { ApplicationArea = All; Editable = false; }
                field("Vendor No."; Rec."Vendor No.") { ApplicationArea = All; Editable = false; }
                field(Amount; Rec.Amount) { ApplicationArea = All; Editable = false; }
                field(Status; Rec.Status) { ApplicationArea = All; Editable = false; }
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

                    if Rec.FindSet() then
                        repeat
                            // Use top date for all rows
                            Rec."Scheduled Date" := DefaultScheduledDate;
                            Rec.Modify(true);
                        until Rec.Next() = 0;

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

            if Status.Get(InvNo) then
                if Status.Status = Status.Status::Paid then begin
                    ErrorText += StrSubstNo('• Invoice %1 is already paid.\n', InvNo);
                    HasErrors := true;
                    continue;
                end;

            Rec.Init();
            Rec."Entry No." := NextEntryNo;
            NextEntryNo += 1;
            Rec."Invoice No." := PayableVLE."Document No.";
            Rec."Vendor No." := PayableVLE."Vendor No.";
            Rec.Amount := Abs(PayableVLE."Remaining Amount");

            // Use top Scheduled Date
            Rec."Scheduled Date" := DefaultScheduledDate;
            Rec.Status := Rec.Status::Open;

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
}
