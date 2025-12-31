
codeunit 50104 "Chiizu Payment Service"
{
    // --------------------------
    // BULK PAYMENT (single API call, robust VLE resolution)
    // --------------------------
    procedure PayInvoices(SelectedInvoiceNos: List of [Code[20]])
    var
        Setup: Record "Chiizu Setup";
        Status: Record "Chiizu Invoice Status";
        VendLedgEntry: Record "Vendor Ledger Entry";
        Payload: JsonObject;
        Invoices: JsonArray;
        Obj: JsonObject;
        InvoiceNosToMarkPaid: List of [Code[20]];
        InvNo: Code[20];
        i: Integer;
        ErrorText: Text;
        HasErrors: Boolean;
        RemainingAmount: Decimal;
        CurrencyCode: Code[10];

        PayableVLE: Record "Vendor Ledger Entry";
        BestRemaining: Decimal;
        FoundPayable: Boolean;
    begin
        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices were provided.');

        GetOrCreateSetup(Setup);

        Clear(Payload);
        Clear(Invoices);
        Clear(InvoiceNosToMarkPaid);
        ErrorText := '';
        HasErrors := false;

        // Validate each invoice and build payload
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

            // Already paid via Chiizu?
            if Status.Get(InvNo) then
                if Status."Paid via Chiizu" then begin
                    ErrorText += StrSubstNo('• Invoice %1 is already paid via Chiizu.\n', InvNo);
                    HasErrors := true;
                    continue;
                end;

            // Build payload item
            PayableVLE.CalcFields("Remaining Amount", "Remaining Amt. (LCY)");
            RemainingAmount := Abs(PayableVLE."Remaining Amount");

            if Round(RemainingAmount, 0.01, '=') = 0 then begin
                ErrorText += StrSubstNo('• Invoice %1 has no remaining payable amount.\n', InvNo);
                HasErrors := true;
                continue;
            end;

            Clear(Obj);
            Obj.Add('invoiceNo', InvNo);
            Obj.Add('vendorNo', PayableVLE."Vendor No.");
            Obj.Add('amount', RemainingAmount);
            Obj.Add('postingDate', Format(PayableVLE."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
            CurrencyCode := PayableVLE."Currency Code";
            if CurrencyCode <> '' then
                Obj.Add('currency', CurrencyCode)
            else
                Obj.Add('currency', 'LCY');

            Invoices.Add(Obj);
            InvoiceNosToMarkPaid.Add(InvNo);
        end;

        if HasErrors then
            Error(ErrorText);

        if Invoices.Count() = 0 then
            Error('None of the selected invoices are payable.');

        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Invoices);

        // Single API call
        CallBulkAPI(Setup, Payload, Setup."API Base URL");

        // Mark paid on success
        for i := 1 to InvoiceNosToMarkPaid.Count() do begin
            InvNo := InvoiceNosToMarkPaid.Get(i);

            if not Status.Get(InvNo) then begin
                Status.Init();
                Status."Invoice No." := InvNo;
                Status."Paid via Chiizu" := true;
                Status."Payment Date" := Today();
                Status.Insert(true);
            end else begin
                Status."Paid via Chiizu" := true;
                Status."Payment Date" := Today();
                Status.Modify(true);
            end;
        end;
    end;

    // --------------------------
    // BULK SCHEDULING (single API call)
    // --------------------------
    procedure ScheduleInvoices(var TempSchedule: Record "Chiizu Scheduled Payment" temporary): Integer
    var
        Setup: Record "Chiizu Setup";
        Status: Record "Chiizu Invoice Status";
        PersistentSchedule: Record "Chiizu Scheduled Payment";
        VendLedgEntry: Record "Vendor Ledger Entry";
        Payload: JsonObject;
        Schedules: JsonArray;
        Obj: JsonObject;
        ErrorText: Text;
        HasErrors: Boolean;
        RemainingAmount: Decimal;
        CurrencyCode: Code[10];
        CountScheduled: Integer;

        PayableVLE: Record "Vendor Ledger Entry";
        BestRemaining: Decimal;
        FoundPayable: Boolean;

        NewEntryNo: Integer;
    begin
        TempSchedule.Reset();
        if TempSchedule.IsEmpty() then
            Error('No invoices were provided.');

        GetOrCreateSetup(Setup);

        Clear(Payload);
        Clear(Schedules);
        ErrorText := '';
        HasErrors := false;
        CountScheduled := 0;

        if TempSchedule.FindSet() then
            repeat
                // Resolve payable VLE: try Open=true first, then fallback
                VendLedgEntry.Reset();
                VendLedgEntry.SetRange("Document Type", VendLedgEntry."Document Type"::Invoice);
                VendLedgEntry.SetRange("Document No.", TempSchedule."Invoice No.");
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

                if not FoundPayable then begin
                    VendLedgEntry.Reset();
                    VendLedgEntry.SetRange("Document Type", VendLedgEntry."Document Type"::Invoice);
                    VendLedgEntry.SetRange("Document No.", TempSchedule."Invoice No.");
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
                    ErrorText += StrSubstNo('• No payable vendor ledger entry found for invoice %1.\n', TempSchedule."Invoice No.");
                    HasErrors := true;
                    continue;
                end;

                // Validate schedule date
                if TempSchedule."Scheduled Date" < Today then begin
                    ErrorText += StrSubstNo('• Scheduled date for invoice %1 must be today or later.\n', TempSchedule."Invoice No.");
                    HasErrors := true;
                    continue;
                end;

                // Disallow scheduling if already paid via Chiizu
                if Status.Get(TempSchedule."Invoice No.") then
                    if Status."Paid via Chiizu" then begin
                        ErrorText += StrSubstNo('• Invoice %1 is already paid via Chiizu.\n', TempSchedule."Invoice No.");
                        HasErrors := true;
                        continue;
                    end;

                // Disallow duplicate active schedule (business rule; adjust if you allow re-scheduling)
                PersistentSchedule.Reset();
                PersistentSchedule.SetRange("Invoice No.", TempSchedule."Invoice No.");
                if PersistentSchedule.FindFirst() then
                    if PersistentSchedule.Status = PersistentSchedule.Status::Scheduled then begin
                        ErrorText += StrSubstNo('• Invoice %1 already has an active schedule.\n', TempSchedule."Invoice No.");
                        HasErrors := true;
                        continue;
                    end;

                // Build schedule payload item
                PayableVLE.CalcFields("Remaining Amount", "Remaining Amt. (LCY)");
                RemainingAmount := Abs(PayableVLE."Remaining Amount");

                if Round(RemainingAmount, 0.01, '=') = 0 then begin
                    ErrorText += StrSubstNo('• Invoice %1 has no remaining payable amount.\n', TempSchedule."Invoice No.");
                    HasErrors := true;
                    continue;
                end;

                Clear(Obj);
                Obj.Add('invoiceNo', TempSchedule."Invoice No.");
                Obj.Add('vendorNo', PayableVLE."Vendor No.");
                Obj.Add('amount', RemainingAmount);
                Obj.Add('scheduledDate', Format(TempSchedule."Scheduled Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                CurrencyCode := PayableVLE."Currency Code";
                if CurrencyCode <> '' then
                    Obj.Add('currency', CurrencyCode)
                else
                    Obj.Add('currency', 'LCY');

                Schedules.Add(Obj);
            until TempSchedule.Next() = 0;

        if HasErrors then
            Error(ErrorText);

        if Schedules.Count() = 0 then
            Error('None of the selected invoices are eligible for scheduling.');

        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Schedules);
        Payload.Add('isScheduled', true);

        // Single scheduling API call
        CallBulkAPI(Setup, Payload, Setup."API Base URL"); // use a dedicated Schedule URL if you have one

        // Persist schedule rows on success (ensure unique Entry No. if your PK is not AutoIncrement)
        TempSchedule.Reset();
        if TempSchedule.FindSet() then
            repeat
                // Compute next Entry No. in persistent table (handles non-AutoIncrement PKs)
                NewEntryNo := GetNextScheduleEntryNo();

                PersistentSchedule.Reset();
                PersistentSchedule.SetRange("Invoice No.", TempSchedule."Invoice No.");
                if PersistentSchedule.FindFirst() then begin
                    // Update existing schedule for the invoice
                    PersistentSchedule."Vendor No." := TempSchedule."Vendor No.";
                    PersistentSchedule.Amount := TempSchedule.Amount;
                    PersistentSchedule."Scheduled Date" := TempSchedule."Scheduled Date";
                    PersistentSchedule.Status := PersistentSchedule.Status::Scheduled;
                    PersistentSchedule.Modify(true);
                end else begin
                    PersistentSchedule.Init();
                    PersistentSchedule."Entry No." := NewEntryNo; // ensure unique PK
                    PersistentSchedule."Invoice No." := TempSchedule."Invoice No.";
                    PersistentSchedule."Vendor No." := TempSchedule."Vendor No.";
                    PersistentSchedule.Amount := TempSchedule.Amount;
                    PersistentSchedule."Scheduled Date" := TempSchedule."Scheduled Date";
                    PersistentSchedule.Status := PersistentSchedule.Status::Scheduled;
                    PersistentSchedule.Insert(true);
                end;

                CountScheduled += 1;
            until TempSchedule.Next() = 0;

        exit(CountScheduled);
    end;

    local procedure GetNextScheduleEntryNo(): Integer
    var
        T: Record "Chiizu Scheduled Payment";
    begin
        T.LockTable();
        if T.FindLast() then
            exit(T."Entry No." + 1);
        exit(1);
    end;

    local procedure CallBulkAPI(Setup: Record "Chiizu Setup"; Payload: JsonObject; Endpoint: Text)
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        Headers: HttpHeaders;
        BodyText: Text;
        ResponseText: Text;
    begin
        Payload.WriteTo(BodyText);
        Content.WriteFrom(BodyText);

        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        Headers := Client.DefaultRequestHeaders();
        Headers.Clear();
        Headers.Add('Authorization', 'Bearer {PASS_TOKEN_HERE}');

        Request.Method := 'POST';
        Request.SetRequestUri(Endpoint);
        Request.Content := Content;

        if not Client.Send(Request, Response) then
            Error('Failed to call Chiizu API.');

        if not Response.IsSuccessStatusCode() then begin
            Response.Content.ReadAs(ResponseText);
            Error('Chiizu request failed. Status: %1, Response: %2',
                  Response.HttpStatusCode(), ResponseText);
        end;
    end;

    local procedure CreateBatchId(): Code[50]
    begin
        exit('BC-' + Format(CurrentDateTime(), 0, '<Year4>-<Month,2>-<Day,2>T<Hour,2>:<Minute,2>:<Second,2>'));
    end;

    local procedure GetOrCreateSetup(var Setup: Record "Chiizu Setup")
    begin
        if not Setup.Get('CHIIZU') then begin
            Setup.Init();
            Setup."Primary Key" := 'CHIIZU';
            Setup.Insert(true);
        end;
    end;
}
