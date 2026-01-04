codeunit 50104 "Chiizu Payment Service"
{
    // --------------------------
    // BULK PAYMENT
    // --------------------------
    procedure PayInvoices(SelectedInvoiceNos: List of [Code[20]])
    var
        Setup: Record "Chiizu Setup";
        VendLedgEntry: Record "Vendor Ledger Entry";
        InvoiceStatus: Record "Chiizu Invoice Status";

        Payload: JsonObject;
        Invoices: JsonArray;
        Obj: JsonObject;

        ResponseText: Text;
        InvNo: Code[20];
        i: Integer;

        PayableVLE: Record "Vendor Ledger Entry";
        RemainingAmount: Decimal;
        FoundPayable: Boolean;
    begin
        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices were provided.');

        GetOrCreateSetup(Setup);

        Clear(Payload);
        Clear(Invoices);

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            FoundPayable := ResolvePayableVLE(InvNo, PayableVLE);
            if not FoundPayable then
                Error('No payable vendor ledger entry found for invoice %1.', InvNo);

            PayableVLE.CalcFields("Remaining Amount");
            RemainingAmount := Abs(PayableVLE."Remaining Amount");

            if Round(RemainingAmount, 0.01, '=') = 0 then
                Error('Invoice %1 has no remaining payable amount.', InvNo);

            Clear(Obj);
            Obj.Add('invoiceNo', InvNo);
            Obj.Add('vendorNo', PayableVLE."Vendor No.");
            Obj.Add('amount', RemainingAmount);
            Obj.Add(
                'postingDate',
                Format(PayableVLE."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>')
            );

            Invoices.Add(Obj);
        end;

        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Invoices);

        ResponseText := CallBulkAPI(Setup, Payload, Setup."API Base URL");
        ApplyApiResult(ResponseText);
    end;

    // --------------------------
    // BULK SCHEDULING
    // --------------------------
    procedure ScheduleInvoices(var TempSchedule: Record "Chiizu Scheduled Payment" temporary): Integer
    var
        Setup: Record "Chiizu Setup";
        Payload: JsonObject;
        Schedules: JsonArray;
        Obj: JsonObject;
        ResponseText: Text;
    begin
        TempSchedule.Reset();
        if TempSchedule.IsEmpty() then
            Error('No invoices were provided.');

        GetOrCreateSetup(Setup);
        Clear(Payload);
        Clear(Schedules);

        if TempSchedule.FindSet() then
            repeat
                Clear(Obj);
                Obj.Add('invoiceNo', TempSchedule."Invoice No.");
                Obj.Add('vendorNo', TempSchedule."Vendor No.");
                Obj.Add('amount', TempSchedule.Amount);
                Obj.Add(
                    'scheduledDate',
                    Format(TempSchedule."Scheduled Date", 0, '<Year4>-<Month,2>-<Day,2>')
                );

                Schedules.Add(Obj);
            until TempSchedule.Next() = 0;

        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Schedules);
        Payload.Add('isScheduled', true);

        ResponseText := CallBulkAPI(Setup, Payload, Setup."API Base URL");
        ApplyApiResult(ResponseText);

        exit(Schedules.Count());
    end;

    // --------------------------
    // BULK CANCEL SCHEDULED PAYMENTS  ✅ NEW
    // --------------------------
    procedure CancelScheduledInvoices(SelectedInvoiceNos: List of [Code[20]])
    var
        Setup: Record "Chiizu Setup";
        InvoiceStatus: Record "Chiizu Invoice Status";

        Payload: JsonObject;
        Invoices: JsonArray;
        Obj: JsonObject;

        ResponseText: Text;
        InvNo: Code[20];
        i: Integer;

        InvalidInvoices: Text;
        HasInvalid: Boolean;
    begin
        if SelectedInvoiceNos.Count() = 0 then
            Error('No invoices were provided.');

        GetOrCreateSetup(Setup);
        Clear(Payload);
        Clear(Invoices);

        HasInvalid := false;
        InvalidInvoices := '';

        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            if not InvoiceStatus.Get(InvNo) then begin
                HasInvalid := true;
                InvalidInvoices +=
                    StrSubstNo('• %1 (no Chiizu record)', InvNo) + '\';
                continue;
            end;

            if InvoiceStatus.Status <> InvoiceStatus.Status::Scheduled then begin
                HasInvalid := true;
                InvalidInvoices +=
                    StrSubstNo(
                        '• %1 (status = %2)',
                        InvNo,
                        InvoiceStatus.Status
                    ) + '\';
            end;
        end;

        if HasInvalid then
            Error(
                'Cancel Scheduled Payment failed.' +
                '\' +
                'The following invoices are not in Scheduled status:' +
                '\' +
                InvalidInvoices
            );


        // ✅ BUILD PAYLOAD (ALL VALID)
        for i := 1 to SelectedInvoiceNos.Count() do begin
            InvNo := SelectedInvoiceNos.Get(i);

            Clear(Obj);
            Obj.Add('invoiceNo', InvNo);
            Obj.Add('action', 'CANCEL');

            Invoices.Add(Obj);
        end;

        Payload.Add('batchId', CreateBatchId());
        Payload.Add('invoices', Invoices);
        Payload.Add('isCancel', true);

        ResponseText := CallBulkAPI(Setup, Payload, Setup."API Base URL");
        ApplyApiResult(ResponseText);
    end;


    // --------------------------
    // APPLY API RESULT → STATUS
    // --------------------------
    local procedure ApplyApiResult(ResponseText: Text)
    var
        Root: JsonObject;
        Results: JsonArray;
        ItemToken: JsonToken;
        FieldToken: JsonToken;

        InvoiceNo: Code[20];
        ApiStatus: Text;
        ScheduledDateTxt: Text;
        ScheduledDate: Date;

        InvoiceStatus: Record "Chiizu Invoice Status";
        EnumStatus: Enum "Chiizu Payment Status";
        i: Integer;
    begin
        if not Root.ReadFrom(ResponseText) then
            Error('Invalid API response.');

        if not Root.Get('invoices', FieldToken) then
            Error('API response missing invoices.');

        Results := FieldToken.AsArray();

        for i := 0 to Results.Count() - 1 do begin
            Results.Get(i, ItemToken);

            ItemToken.AsObject().Get('invoiceNo', FieldToken);
            InvoiceNo := FieldToken.AsValue().AsCode();

            ItemToken.AsObject().Get('status', FieldToken);
            ApiStatus := UpperCase(FieldToken.AsValue().AsText());
            EnumStatus := MapApiStatus(ApiStatus);

            Clear(ScheduledDate);
            if ItemToken.AsObject().Get('scheduledDate', FieldToken) then begin
                ScheduledDateTxt := FieldToken.AsValue().AsText();
                Evaluate(ScheduledDate, ScheduledDateTxt);
            end;

            if not InvoiceStatus.Get(InvoiceNo) then begin
                InvoiceStatus.Init();
                InvoiceStatus."Invoice No." := InvoiceNo;
                InvoiceStatus.Status := EnumStatus;
                InvoiceStatus."Scheduled Date" := ScheduledDate;
                InvoiceStatus.Insert(true);
            end else begin
                InvoiceStatus.Status := EnumStatus;
                InvoiceStatus."Scheduled Date" := ScheduledDate;
                InvoiceStatus.Modify(true);
            end;
        end;
    end;

    // --------------------------
    // API → ENUM MAPPING
    // --------------------------
    local procedure MapApiStatus(ApiStatus: Text): Enum "Chiizu Payment Status"
    begin
        case ApiStatus of
            'PAID':
                exit("Chiizu Payment Status"::Paid);
            'PROCESSING':
                exit("Chiizu Payment Status"::Processing);
            'SCHEDULED':
                exit("Chiizu Payment Status"::Scheduled);
            'FAILED':
                exit("Chiizu Payment Status"::Failed);
            'CANCELLED':
                exit("Chiizu Payment Status"::Cancelled);
            else
                exit("Chiizu Payment Status"::Open);
        end;
    end;

    // --------------------------
    // HELPERS
    // --------------------------
    local procedure ResolvePayableVLE(InvNo: Code[20]; var PayableVLE: Record "Vendor Ledger Entry"): Boolean
    var
        VLE: Record "Vendor Ledger Entry";
    begin
        VLE.SetRange("Document Type", VLE."Document Type"::Invoice);
        VLE.SetRange("Document No.", InvNo);
        VLE.SetRange(Open, true);

        if VLE.FindFirst() then begin
            PayableVLE := VLE;
            exit(true);
        end;

        exit(false);
    end;

    local procedure CallBulkAPI(Setup: Record "Chiizu Setup"; Payload: JsonObject; Endpoint: Text): Text
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

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Chiizu request failed. %1', ResponseText);

        exit(ResponseText);
    end;

    local procedure CreateBatchId(): Code[50]
    begin
        exit(
            'BC-' +
            Format(
                CurrentDateTime(),
                0,
                '<Year4>-<Month,2>-<Day,2>T<Hour,2>:<Minute,2>:<Second,2>'
            )
        );
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
