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

        // 🔗 API call (returns raw response text)
        ResponseText := CallBulkAPI(Setup, Payload, Setup."API Base URL");

        // ✅ Status is updated ONLY based on API response
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
        CountScheduled: Integer;
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

        CountScheduled := Schedules.Count();
        exit(CountScheduled);
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

        InvoiceStatus: Record "Chiizu Invoice Status";
        EnumStatus: Enum "Chiizu Payment Status";
        i: Integer;
    begin
        if not Root.ReadFrom(ResponseText) then
            Error('Invalid API response.');

        if not Root.Get('invoices', FieldToken) then
            Error('API response missing results.');

        Results := FieldToken.AsArray();

        for i := 0 to Results.Count() - 1 do begin
            Results.Get(i, ItemToken);

            // invoiceNo
            if not ItemToken.AsObject().Get('invoiceNo', FieldToken) then
                Error('API result missing invoiceNo.');

            InvoiceNo := FieldToken.AsValue().AsCode();

            // status
            if not ItemToken.AsObject().Get('status', FieldToken) then
                Error('API result missing status.');

            ApiStatus := UpperCase(FieldToken.AsValue().AsText());

            EnumStatus := MapApiStatus(ApiStatus);

            if not InvoiceStatus.Get(InvoiceNo) then begin
                InvoiceStatus.Init();
                InvoiceStatus."Invoice No." := InvoiceNo;
                InvoiceStatus.Status := EnumStatus;
                InvoiceStatus.Insert(true);
            end else begin
                InvoiceStatus.Status := EnumStatus;
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
